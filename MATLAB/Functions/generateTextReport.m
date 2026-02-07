function generateTextReport(data, stabilityData, config)
    % GENERATETEXTREPORT Generates text report for Florent analysis
    %
    % Usage:
    %   generateTextReport(data, stabilityData, config)
    %
    % Generates:
    %   - Executive summary
    %   - Key findings
    %   - Quadrant distribution
    %   - Recommendations
    %   - MC statistics
    
    if nargin < 3
        config = loadFlorentConfig();
    end
    
    fprintf('Generating text report...\n');
    
    % Create report file
    reportFile = fullfile(config.paths.reportsDir, ...
        sprintf('florent_report_%s_%s.txt', data.projectId, data.firmId));
    
    fid = fopen(reportFile, 'w');
    if fid == -1
        error('Failed to create report file: %s', reportFile);
    end
    
    try
        % Write report
        writeHeader(fid, data, stabilityData);
        
        if config.report.includeExecutiveSummary
            writeExecutiveSummary(fid, data, stabilityData);
        end
        
        if config.report.includeDetailedAnalysis
            writeDetailedAnalysis(fid, data, stabilityData);
        end
        
        writeRecommendations(fid, stabilityData);
        
        if config.report.includeMethodology
            writeMethodology(fid, config);
        end
        
        if config.report.includeAppendices
            writeAppendices(fid, data, stabilityData, config);
        end
        
        fprintf('Text report generated: %s\n', reportFile);
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    
    fclose(fid);
end

function writeHeader(fid, data, stabilityData)
    % Write report header
    
    fprintf(fid, '========================================\n');
    fprintf(fid, '  FLORENT RISK ANALYSIS REPORT\n');
    fprintf(fid, '========================================\n\n');
    fprintf(fid, 'Generated: %s\n', datestr(now));
    fprintf(fid, 'Project ID: %s\n', data.projectId);
    fprintf(fid, 'Firm ID: %s\n', data.firmId);
    fprintf(fid, 'Total Nodes Analyzed: %d\n', length(stabilityData.nodeIds));
    fprintf(fid, '\n');
end

function writeExecutiveSummary(fid, data, stabilityData)
    % Write executive summary
    
    fprintf(fid, '========================================\n');
    fprintf(fid, 'EXECUTIVE SUMMARY\n');
    fprintf(fid, '========================================\n\n');
    
    % Key metrics
    avgStability = mean(stabilityData.overallStability);
    avgRisk = mean(stabilityData.meanScores.risk);
    avgInfluence = mean(stabilityData.meanScores.influence);
    
    fprintf(fid, 'Key Metrics:\n');
    fprintf(fid, '  Average Stability Score: %.3f\n', avgStability);
    fprintf(fid, '  Average Risk Score: %.3f\n', avgRisk);
    fprintf(fid, '  Average Influence Score: %.3f\n', avgInfluence);
    fprintf(fid, '\n');
    
    % Stability assessment
    if avgStability >= 0.7
        stabilityLevel = 'High';
    elseif avgStability >= 0.5
        stabilityLevel = 'Moderate';
    else
        stabilityLevel = 'Low';
    end
    
    fprintf(fid, 'Overall Stability Assessment: %s\n', stabilityLevel);
    fprintf(fid, '\n');
    
    % Top risks
    [~, riskRank] = sort(stabilityData.meanScores.risk, 'descend');
    topRisks = riskRank(1:min(5, length(riskRank)));
    
    fprintf(fid, 'Top 5 Highest Risk Nodes:\n');
    for i = 1:length(topRisks)
        idx = topRisks(i);
        fprintf(fid, '  %d. %s (Risk: %.3f)\n', i, ...
            stabilityData.nodeIds{idx}, stabilityData.meanScores.risk(idx));
    end
    fprintf(fid, '\n');
    
    % Unstable nodes
    unstableIdx = find(stabilityData.overallStability < config.thresholds.stabilityThreshold);
    fprintf(fid, 'Unstable Nodes (< %.2f stability): %d (%.1f%%)\n', ...
        config.thresholds.stabilityThreshold, length(unstableIdx), ...
        100*length(unstableIdx)/length(stabilityData.nodeIds));
    fprintf(fid, '\n');
end

function writeDetailedAnalysis(fid, data, stabilityData)
    % Write detailed analysis
    
    fprintf(fid, '========================================\n');
    fprintf(fid, 'DETAILED ANALYSIS\n');
    fprintf(fid, '========================================\n\n');
    
    % Quadrant distribution
    risk = stabilityData.meanScores.risk;
    influence = stabilityData.meanScores.influence;
    quadrants = classifyQuadrant(risk, influence);
    
    fprintf(fid, 'Quadrant Distribution:\n');
    q1Count = sum(strcmp(quadrants, 'Q1'));
    q2Count = sum(strcmp(quadrants, 'Q2'));
    q3Count = sum(strcmp(quadrants, 'Q3'));
    q4Count = sum(strcmp(quadrants, 'Q4'));
    total = length(quadrants);
    
    fprintf(fid, '  Q1 (Mitigate - High Risk, High Influence): %d (%.1f%%)\n', ...
        q1Count, 100*q1Count/total);
    fprintf(fid, '  Q2 (Automate - Low Risk, High Influence): %d (%.1f%%)\n', ...
        q2Count, 100*q2Count/total);
    fprintf(fid, '  Q3 (Contingency - High Risk, Low Influence): %d (%.1f%%)\n', ...
        q3Count, 100*q3Count/total);
    fprintf(fid, '  Q4 (Delegate - Low Risk, Low Influence): %d (%.1f%%)\n', ...
        q4Count, 100*q4Count/total);
    fprintf(fid, '\n');
    
    % Node-by-node analysis (top unstable)
    unstableIdx = find(stabilityData.overallStability < config.thresholds.stabilityThreshold);
    [~, sortIdx] = sort(stabilityData.overallStability(unstableIdx), 'ascend');
    unstableIdx = unstableIdx(sortIdx);
    
    fprintf(fid, 'Most Unstable Nodes:\n');
    nShow = min(10, length(unstableIdx));
    for i = 1:nShow
        idx = unstableIdx(i);
        fprintf(fid, '  %d. %s\n', i, stabilityData.nodeIds{idx});
        fprintf(fid, '     Stability: %.3f, Risk: %.3f, Influence: %.3f, Quadrant: %s\n', ...
            stabilityData.overallStability(idx), ...
            stabilityData.meanScores.risk(idx), ...
            stabilityData.meanScores.influence(idx), ...
            quadrants{idx});
    end
    fprintf(fid, '\n');
end

function writeRecommendations(fid, stabilityData)
    % Write recommendations
    
    fprintf(fid, '========================================\n');
    fprintf(fid, 'RECOMMENDATIONS\n');
    fprintf(fid, '========================================\n\n');
    
    risk = stabilityData.meanScores.risk;
    influence = stabilityData.meanScores.influence;
    quadrants = classifyQuadrant(risk, influence);
    
    % Recommendations by quadrant
    fprintf(fid, 'Strategic Actions by Quadrant:\n\n');
    
    q1Idx = find(strcmp(quadrants, 'Q1'));
    if ~isempty(q1Idx)
        fprintf(fid, 'Q1 - Mitigate (%d nodes):\n', length(q1Idx));
        fprintf(fid, '  These nodes have high risk and high influence.\n');
        fprintf(fid, '  Recommendation: Direct oversight, custom workflows, dedicated resources.\n\n');
    end
    
    q2Idx = find(strcmp(quadrants, 'Q2'));
    if ~isempty(q2Idx)
        fprintf(fid, 'Q2 - Automate (%d nodes):\n', length(q2Idx));
        fprintf(fid, '  These nodes have low risk and high influence.\n');
        fprintf(fid, '  Recommendation: Standard operating procedures, automation where possible.\n\n');
    end
    
    q3Idx = find(strcmp(quadrants, 'Q3'));
    if ~isempty(q3Idx)
        fprintf(fid, 'Q3 - Contingency (%d nodes):\n', length(q3Idx));
        fprintf(fid, '  These nodes have high risk and low influence (CRITICAL).\n');
        fprintf(fid, '  Recommendation: Insurance, legal indemnification, backup plans.\n\n');
    end
    
    q4Idx = find(strcmp(quadrants, 'Q4'));
    if ~isempty(q4Idx)
        fprintf(fid, 'Q4 - Delegate (%d nodes):\n', length(q4Idx));
        fprintf(fid, '  These nodes have low risk and low influence.\n');
        fprintf(fid, '  Recommendation: Subcontract or monitor minimally.\n\n');
    end
    
    % Unstable nodes recommendation
    unstableIdx = find(stabilityData.overallStability < 0.5);
    if ~isempty(unstableIdx)
        fprintf(fid, 'Unstable Nodes (%d nodes):\n', length(unstableIdx));
        fprintf(fid, '  These nodes show high variance in classification across MC iterations.\n');
        fprintf(fid, '  Recommendation: Manual review, additional analysis, conservative approach.\n\n');
    end
end

function writeMethodology(fid, config)
    % Write methodology section
    
    fprintf(fid, '========================================\n');
    fprintf(fid, 'METHODOLOGY\n');
    fprintf(fid, '========================================\n\n');
    
    fprintf(fid, 'Monte Carlo Configuration:\n');
    fprintf(fid, '  Iterations per simulation: %d\n', config.monteCarlo.nIterations);
    fprintf(fid, '  Parallel execution: %s\n', mat2str(config.monteCarlo.useParallel));
    fprintf(fid, '\n');
    
    fprintf(fid, 'Analysis Framework:\n');
    fprintf(fid, '  - Parameter Sensitivity Analysis\n');
    fprintf(fid, '  - Cross-Encoder Uncertainty Analysis\n');
    fprintf(fid, '  - Topology Stress Testing\n');
    fprintf(fid, '  - Failure Probability Distributions\n');
    fprintf(fid, '\n');
    
    fprintf(fid, 'Risk Calculation:\n');
    fprintf(fid, '  Influence Score: I_n = sigma(CE) * delta^(-d)\n');
    fprintf(fid, '  Cascading Risk: P(S_n) = (1 - P(f_local) * mu) * Product(P(S_i))\n');
    fprintf(fid, '\n');
end

function writeAppendices(fid, data, stabilityData, config)
    % Write appendices
    
    fprintf(fid, '========================================\n');
    fprintf(fid, 'APPENDICES\n');
    fprintf(fid, '========================================\n\n');
    
    fprintf(fid, 'Configuration Parameters:\n');
    fprintf(fid, '  Attenuation Factor: %.2f\n', data.parameters.attenuation_factor);
    fprintf(fid, '  Risk Multiplier: %.2f\n', data.parameters.risk_multiplier);
    fprintf(fid, '\n');
    
    fprintf(fid, 'File Locations:\n');
    fprintf(fid, '  Data Directory: %s\n', config.paths.dataDir);
    fprintf(fid, '  Figures Directory: %s\n', config.paths.figuresDir);
    fprintf(fid, '  Reports Directory: %s\n', config.paths.reportsDir);
    fprintf(fid, '\n');
end

