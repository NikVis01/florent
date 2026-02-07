function action = getActionFromQuadrant(quadrant)
    % GETACTIONFROMQUADRANT Returns strategic action for a quadrant
    %
    % Input:
    %   quadrant - Quadrant label ('Q1', 'Q2', 'Q3', 'Q4')
    %
    % Output:
    %   action - Strategic action string
    
    switch quadrant
        case 'Q1'
            action = 'Mitigate';
        case 'Q2'
            action = 'Automate';
        case 'Q3'
            action = 'Contingency';
        case 'Q4'
            action = 'Delegate';
        otherwise
            action = 'Unknown';
    end
end

