#include <cmath>
#include <algorithm>
#include <vector>

extern "C" {
    /**
     * Calculates the cosine similarity between two float vectors.
     */
    float cosine_similarity(const float* v1, const float* v2, int size) {
        float dot = 0.0f, norm_v1 = 0.0f, norm_v2 = 0.0f;
        for (int i = 0; i < size; ++i) {
            dot += v1[i] * v2[i];
            norm_v1 += v1[i] * v1[i];
            norm_v2 += v2[i] * v2[i];
        }
        if (norm_v1 == 0 || norm_v2 == 0) return 0.0f;
        return dot / (std::sqrt(norm_v1) * std::sqrt(norm_v2));
    }

    /**
     * Calculates the influence score: I_n = similarity * centrality.
     */
    float calculate_influence_tensor(const float* firm_tensor, const float* node_tensor, int size, float centrality) {
        float sim = cosine_similarity(firm_tensor, node_tensor, size);
        return sim * centrality;
    }

    /**
     * Calculates cascading probability of success.
     * P(Success_n) = (1 - P(Failure_local) * multiplier) * Product(P(Success_parents))
     */
    float propagate_risk(float local_failure_prob, float multiplier, const float* parent_probs, int num_parents) {
        float local_p_success = 1.0f - std::min(1.0f, local_failure_prob * multiplier);
        float parent_p_success = 1.0f;
        for (int i = 0; i < num_parents; ++i) {
            parent_p_success *= parent_probs[i];
        }
        return local_p_success * parent_p_success;
    }
}
