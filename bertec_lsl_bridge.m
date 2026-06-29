%% 1. Configuration & Setup (Corrected .NET Architecture)
clear; clc;

fprintf('Loading Bertec .NET Assembly...\n');

try
    % STRATEGY A: Attempt to load from the Windows Global Cache (GAC)
    % If the Bertec installer was run on this machine, the 64-bit version 
    % is registered in Windows. MATLAB can pull it automatically without a file path!
    asm = NET.addAssembly('BertecDevice');
    fprintf('Success! Loaded 64-bit Bertec Assembly from system registry.\n');
    
catch
    try
        % STRATEGY B: Look for the specific x64 (64-bit) folder path
        % Update the directory to match your Bertec SDK location, ensuring it includes \x64\
        bertec_dll_path = 'C:\Users\YOUR_USERNAME\Downloads\Bertec_SDK\x64\BertecDevice.dll'; 
        
        asm = NET.addAssembly(bertec_dll_path);
        fprintf('Success! Loaded 64-bit Bertec Assembly from x64 folder.\n');
        
    catch ME
        % If both strategies fail, display a clean diagnostic warning
        fprintf('\n--- ARCHITECTURE ERROR DETAILS ---\n');
        fprintf('MATLAB Architecture: %s\n', computer);
        fprintf('Error message: %s\n', ME.message);
        error('Could not find the 64-bit version of the Bertec DLL. Please ensure you are not using the 32-bit (x86) version.');
    end
end

% Initialize the device manager object through MATLAB
deviceManager = Bertec.Device.DeviceManager();
deviceManager.Initialize();
fprintf('Bertec hardware initialized successfully!\n');
