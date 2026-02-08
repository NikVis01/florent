"""
Cross-Encoder client for BGE-M3 reranker inference.
Connects to HuggingFace text-embeddings-inference container.
"""
import requests
import numpy as np
from typing import List, Tuple
import logging
from src.models.entities import Firm
from src.models.graph import Node

logger = logging.getLogger(__name__)


class CrossEncoderClient:
    """Client for BGE-M3 cross-encoder inference service."""

    def __init__(self, endpoint: str = "http://localhost:8080"):
        self.endpoint = endpoint
        self._check_health()

    def _check_health(self):
        """Verify cross-encoder service is available."""
        try:
            response = requests.get(f"{self.endpoint}/health", timeout=2)
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

    def rerank(self, query: str, passages: List[str]) -> List[float]:
        """
        Use BGE-M3 to score query-passage pairs via embeddings + cosine similarity.

        Args:
            query: Query text (firm capabilities)
            passages: List of passage texts (node requirements)

        Returns:
            List of scores (0-1 range)
        """
        try:
            # Get embeddings for query
            query_response = requests.post(
                f"{self.endpoint}/vectors",
                json={"text": query},
                timeout=10
            )
            query_response.raise_for_status()
            query_vec = np.array(query_response.json()["vector"])

            # Get embeddings for passages
            scores = []
            for passage in passages:
                passage_response = requests.post(
                    f"{self.endpoint}/vectors",
                    json={"text": passage},
                    timeout=10
                )
                passage_response.raise_for_status()
                passage_vec = np.array(passage_response.json()["vector"])

                # Cosine similarity
                similarity = np.dot(query_vec, passage_vec) / (
                    np.linalg.norm(query_vec) * np.linalg.norm(passage_vec)
                )

                # Normalize to 0-1 range (cosine is -1 to 1)
                score = (similarity + 1.0) / 2.0
                scores.append(float(score))

            return scores

        except Exception as e:
            logger.error("rerank_failed", error=str(e))
            # Fallback to neutral score
            return [0.5] * len(passages)

    def score_firm_node(self, firm: Firm, node: Node) -> float:
        """
        Calculate cross-attention score between firm and node.

        Args:
            firm: Firm object with capabilities
            node: Node object with requirements

        Returns:
            Similarity score (0-1)
        """
        firm_text = self._text_from_firm(firm)
        node_text = self._text_from_node(node)

        scores = self.rerank(firm_text, [node_text])
        return scores[0]

    def score_firm_nodes(self, firm: Firm, nodes: List[Node]) -> List[Tuple[Node, float]]:
        """
        Batch score multiple nodes against a firm.

        Args:
            firm: Firm object
            nodes: List of nodes to score

        Returns:
            List of (node, score) tuples
        """
        firm_text = self._text_from_firm(firm)
        node_texts = [self._text_from_node(node) for node in nodes]

        scores = self.rerank(firm_text, node_texts)

        return list(zip(nodes, scores))
