# Makefile for Project Florent Core Math (C++)

CXX = g++
CXXFLAGS = -fPIC -O3 -shared
TARGET = libtensor_ops.so
SRC = src/services/agent/ops/tensor_ops.cpp

all: build test

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SRC)

build: $(TARGET)

test: build
	pytest tests/

clean:
	rm -f $(TARGET)

.PHONY: all build test clean
