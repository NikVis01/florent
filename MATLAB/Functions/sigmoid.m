function y = sigmoid(x)
    % SIGMOID Standard sigmoid function for mapping raw scores to (0, 1)
    %
    % y = 1 / (1 + exp(-x))
    %
    % Inputs:
    %   x - Input value (scalar, vector, or matrix)
    %
    % Output:
    %   y - Sigmoid output in (0, 1)
    
    y = 1 ./ (1 + exp(-x));
end

