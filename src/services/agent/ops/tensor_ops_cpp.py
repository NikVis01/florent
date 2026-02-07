import ctypes
import os
import numpy as np
from typing import List

# Path to the shared library
LIB_PATH = os.path.join(os.getcwd(), "libtensor_ops.so")

# Load the library
try:
    _lib = ctypes.CDLL(LIB_PATH)
except OSError:
    # During development/local execution, try current directory
    _lib = ctypes.CDLL("./libtensor_ops.so")

# Function Signatures
_lib.cosine_similarity.argtypes = [ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float), ctypes.c_int]
_lib.cosine_similarity.restype = ctypes.c_float

_lib.calculate_influence_tensor.argtypes = [ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float), ctypes.c_int, ctypes.c_float]
_lib.calculate_influence_tensor.restype = ctypes.c_float

_lib.propagate_risk.argtypes = [ctypes.c_float, ctypes.c_float, ctypes.POINTER(ctypes.c_float), ctypes.c_int]
_lib.propagate_risk.restype = ctypes.c_float

def cosine_similarity(v1: List[float], v2: List[float]) -> float:
    size = len(v1)
    c_v1 = (ctypes.c_float * size)(*v1)
    c_v2 = (ctypes.c_float * size)(*v2)
    return _lib.cosine_similarity(c_v1, c_v2, size)

def calculate_influence_tensor(firm_tensor: List[float], node_tensor: List[float], centrality: float) -> float:
    size = len(firm_tensor)
    c_firm = (ctypes.c_float * size)(*firm_tensor)
    c_node = (ctypes.c_float * size)(*node_tensor)
    return _lib.calculate_influence_tensor(c_firm, c_node, size, centrality)

def propagate_risk(local_failure_prob: float, multiplier: float, parent_probs: List[float]) -> float:
    num_parents = len(parent_probs)
    c_parents = (ctypes.c_float * num_parents)(*parent_probs)
    return _lib.propagate_risk(local_failure_prob, multiplier, c_parents, num_parents)
