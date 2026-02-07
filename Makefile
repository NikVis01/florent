# Makefile for Project Florent Core Math (C++)

CXX = g++
CXXFLAGS = -fPIC -O3 -shared
TARGET = libtensor_ops.so
SRC = src/services/agent/tensor_ops.cpp

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SRC)

clean:
	rm -f $(TARGET)

build: clean all
