"""
Cross-Encoder client for BGE-M3 reranker inference.
Connects to HuggingFace text-embeddings-inference container.
"""
import time
import requests
import numpy as np
from typing import List, Tuple
from datetime import datetime

from src.models.entities import Firm
from src.models.graph import Node
from src.models.scoring import CrossEncoderScore, FirmNodeScore
from src.settings import settings
from src.services.logging import get_logger

logger = get_logger(__name__)


class CrossEncoderClient:
    """Client for BGE-M3 cross-encoder inference service."""

    def __init__(self, endpoint: str = None, config=None):
        """
        Initialize cross-encoder client.

        Args:
            endpoint: Override endpoint URL (optional, uses settings if None)
            config: Override CrossEncoderConfig (optional, uses settings if None)
        """
        self.config = config or settings.cross_encoder
        self.endpoint = endpoint or self.config.endpoint
        self._check_health()

    def _check_health(self):
        """Verify cross-encoder service is available."""
        try:
            response = requests.get(
                f"{self.endpoint}/health",
                timeout=self.config.health_timeout
            )
            if response.status_code == 200:
                logger.info("cross_encoder_connected", endpoint=self.endpoint)
            else:
                logger.warning("cross_encoder_unhealthy", status=response.status_code)
        except Exception as e:
            logger.error("cross_encoder_unavailable", error=str(e))
            raise ConnectionError(f"Cross-encoder service unavailable at {self.endpoint}: {e}")

    def _text_from_firm(self, firm: Firm) -> str:
        """Convert firm object to text representation for embedding."""
        sectors = ", ".join(s.name for s in firm.sectors)
        services = ", ".join(s.name for s in firm.services)
        countries = ", ".join(c.a3 for c in firm.countries_active)
        focuses = ", ".join(f.name for f in firm.strategic_focuses)

        return (
            f"{firm.name}. "
            f"Description: {firm.description}. "
            f"Sectors: {sectors}. "
            f"Services: {services}. "
            f"Active in: {countries}. "
            f"Strategic focuses: {focuses}. "
            f"Preferred timeline: {firm.prefered_project_timeline} months."
        )

    def _text_from_node(self, node: Node) -> str:
        """Convert node object to text representation for embedding."""
        return (
            f"{node.name}. "
            f"Type: {node.type.name}. "
            f"Category: {node.type.category}. "
            f"Description: {node.type.description}."
        )

    def embed(self, text: str) -> List[float]:
        """
        Get BGE-M3 embedding for a single text.

        Args:
            text: Text to embed

        Returns:
            List of floats (vector)
        """
        try:
            response = requests.post(
                f"{self.endpoint}/vectors",
                json={"text": text},
                timeout=self.config.request_timeout
            )
            response.raise_for_status()
            return response.json()["vector"]
        except Exception as e:
            logger.error("embed_failed", text=text[:50]+"...", error=str(e))
            # Return a small zero vector if everything fails (BGE-M3 is 1024 dims)
            return [0.0] * 1024

    def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """
        Get BGE-M3 embeddings for multiple texts.

        Args:
            texts: List of texts to embed

        Returns:
            List of vectors
        """
        # For simplicity and given the current TEI setup, we'll do sequential calls
        # or we could use the /embed endpoint if TEI supports it across batches.
        # Here we follow the logic in rerank().
        return [self.embed(t) for t in texts]

    def rerank(self, query: str, passages: List[str]) -> List[CrossEncoderScore]:
        """
        Use BGE-M3 to score query-passage pairs via embeddings + cosine similarity.

        Args:
            query: Query text (firm capabilities)
            passages: List of passage texts (node requirements)

        Returns:
            List of CrossEncoderScore objects with full scoring context
        """
        start_time = time.time()
        scores = []

        try:
            # Get embeddings for query
            query_response = requests.post(
                f"{self.endpoint}/vectors",
                json={"text": query},
                timeout=self.config.request_timeout
            )
            query_response.raise_for_status()
            query_vec = np.array(query_response.json()["vector"])

            # Get embeddings for passages
            for passage in passages:
                passage_response = requests.post(
                    f"{self.endpoint}/vectors",
                    json={"text": passage},
                    timeout=self.config.request_timeout
                )
                passage_response.raise_for_status()
                passage_vec = np.array(passage_response.json()["vector"])

                # Cosine similarity
                similarity = np.dot(query_vec, passage_vec) / (
                    np.linalg.norm(query_vec) * np.linalg.norm(passage_vec)
                )

                # Normalize to 0-1 range (cosine is -1 to 1)
                normalized_score = (similarity + 1.0) / 2.0

                scores.append(CrossEncoderScore(
                    query_text=query,
                    passage_text=passage,
                    similarity_score=float(normalized_score),
                    raw_cosine=float(similarity),
                    timestamp=datetime.now(),
                    metadata={
                        "endpoint": self.endpoint,
                        "model": "BGE-M3"
                    }
                ))

            elapsed_ms = (time.time() - start_time) * 1000
            logger.debug(
                "rerank_complete",
                passages=len(passages),
                elapsed_ms=round(elapsed_ms, 2)
            )

            return scores

        except Exception as e:
            logger.error("rerank_failed", error=str(e))
            # Fallback to neutral score using config
            fallback_score = self.config.fallback_score
            return [
                CrossEncoderScore(
                    query_text=query,
                    passage_text=passage,
                    similarity_score=fallback_score,
                    raw_cosine=0.0,
                    timestamp=datetime.now(),
                    metadata={
                        "endpoint": self.endpoint,
                        "error": str(e),
                        "fallback": True
                    }
                )
                for passage in passages
            ]

    def rerank_simple(self, query: str, passages: List[str]) -> List[float]:
        """
        Legacy method: returns just the scores as floats.

        Args:
            query: Query text
            passages: List of passage texts

        Returns:
            List of scores (0-1 range)

        Note: Prefer using rerank() for structured output.
        """
        scores = self.rerank(query, passages)
        return [score.similarity_score for score in scores]

    def score_firm_node(self, firm: Firm, node: Node) -> FirmNodeScore:
        """
        Calculate cross-attention score between firm and node.

        Args:
            firm: Firm object with capabilities
            node: Node object with requirements

        Returns:
            FirmNodeScore with full scoring context
        """
        start_time = time.time()

        firm_text = self._text_from_firm(firm)
        node_text = self._text_from_node(node)

        scores = self.rerank(firm_text, [node_text])
        cross_encoder_score = scores[0]

        elapsed_ms = (time.time() - start_time) * 1000

        result = FirmNodeScore(
            firm=firm,
            node=node,
            cross_encoder_score=cross_encoder_score.similarity_score,
            firm_text=firm_text,
            node_text=node_text,
            timestamp=datetime.now(),
            metadata={
                "endpoint": self.endpoint,
                "raw_cosine": cross_encoder_score.raw_cosine,
                "elapsed_ms": round(elapsed_ms, 2)
            }
        )

        logger.debug(
            "firm_node_scored",
            firm_id=firm.id,
            node_id=node.id,
            score=round(result.cross_encoder_score, 3),
            elapsed_ms=round(elapsed_ms, 2)
        )

        return result

    def score_firm_node_simple(self, firm: Firm, node: Node) -> float:
        """
        Legacy method: returns just the score as a float.

        Args:
            firm: Firm object
            node: Node object

        Returns:
            Similarity score (0-1)

        Note: Prefer using score_firm_node() for structured output.
        """
        result = self.score_firm_node(firm, node)
        return result.cross_encoder_score

    def score_firm_nodes(self, firm: Firm, nodes: List[Node]) -> List[FirmNodeScore]:
        """
        Score multiple nodes against a firm.

        Args:
            firm: Firm object
            nodes: List of nodes to score

        Returns:
            List of FirmNodeScore objects
        """
        start_time = time.time()

        firm_text = self._text_from_firm(firm)
        node_texts = [self._text_from_node(node) for node in nodes]

        cross_encoder_scores = self.rerank(firm_text, node_texts)

        results = []
        for node, ce_score in zip(nodes, cross_encoder_scores):
            result = FirmNodeScore(
                firm=firm,
                node=node,
                cross_encoder_score=ce_score.similarity_score,
                firm_text=firm_text,
                node_text=self._text_from_node(node),
                timestamp=datetime.now(),
                metadata={
                    "endpoint": self.endpoint,
                    "raw_cosine": ce_score.raw_cosine
                }
            )
            results.append(result)

        elapsed_ms = (time.time() - start_time) * 1000
        logger.info(
            "firm_nodes_scored",
            firm_id=firm.id,
            node_count=len(nodes),
            elapsed_ms=round(elapsed_ms, 2)
        )

        return results

    def score_firm_nodes_simple(self, firm: Firm, nodes: List[Node]) -> List[Tuple[Node, float]]:
        """
        Legacy method: returns (node, score) tuples.

        Args:
            firm: Firm object
            nodes: List of nodes

        Returns:
            List of (node, score) tuples

        Note: Prefer using score_firm_nodes() for structured output.
        """
        results = self.score_firm_nodes(firm, nodes)
        return [result.to_tuple() for result in results]
