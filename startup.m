%% startup.m
% -------------------------------------------------------------------------
% PURPOSE: Initialize the AutomationForExoskeleton Project
% -------------------------------------------------------------------------

function startup()
    clc;
    fprintf('===========================================================\n');
    fprintf('   Initializing AutomationForExoskeleton Project Environment\n');
    fprintf('===========================================================\n');

    %% 1. Path Management
    % Get project root
    projectRoot = fileparts(mfilename('fullpath'));
    fprintf('Project Root: %s\n', projectRoot);
    
    % Define paths individually to avoid concatenation errors
    configPath  = fullfile(projectRoot, 'config');
    scriptsPath = fullfile(projectRoot, 'scripts');
    utilsPath   = fullfile(projectRoot, 'scripts', 'utils');
    testsPath   = fullfile(projectRoot, 'tests');
    srcPath     = fullfile(projectRoot, 'src');
    
    % Initialize list with standard folders
    pathsToAdd = {configPath; scriptsPath; utilsPath; testsPath};

    % Add 'src' and all its subfolders (if it exists)
    if exist(srcPath, 'dir')
        % genpath returns a single long string of paths separated by colons/semicolons
        % We add it as a single entry; addpath handles the delimiters.
        pathsToAdd{end+1, 1} = genpath(srcPath); 
    end

    fprintf('Setting up paths...\n');
    
    % Add paths safely
    for i = 1:length(pathsToAdd)
        p = pathsToAdd{i};
        if ~isempty(p)
            addpath(p);
        end
    end
    
    % (Optional) Save path so you don't have to run this every time
    % savepath; 

    fprintf('  [OK] Source, Config, and Script paths added.\n');

    %% 2. Environment Setup
    % Ensure 'results' folder exists
    resultsDir = fullfile(projectRoot, 'results');
    if ~exist(resultsDir, 'dir')
        mkdir(resultsDir);
        fprintf('  [OK] Created missing ''results'' directory.\n');
    end

    %% 3. Check Toolboxes
    fprintf('Checking dependencies...\n');
    requiredToolboxes = {
        'Statistics and Machine Learning Toolbox', 'fitcsvm';
        'Sensor Fusion and Tracking Toolbox',      'imufilter';
        'Signal Processing Toolbox',               'fft'
    };
    
    missingCount = 0;
    for k = 1:size(requiredToolboxes, 1)
        tbName = requiredToolboxes{k, 1};
        funcCheck = requiredToolboxes{k, 2};
        
        if isempty(which(funcCheck))
            fprintf('  [WARNING] Missing: %s (needed for %s)\n', tbName, funcCheck);
            missingCount = missingCount + 1;
        else
            fprintf('  [OK] Found: %s\n', tbName);
        end
    end

    %% 4. Sanity Check
    try
        cfg = ExoConfig();
        fprintf('  [OK] Configuration loaded (Fs=%d).\n', cfg.FS);
    catch
        fprintf('  [NOTE] ExoConfig not found or errored. (Normal if project is empty)\n');
    end

    fprintf('===========================================================\n');
    fprintf(' Initialization Complete.\n');
end