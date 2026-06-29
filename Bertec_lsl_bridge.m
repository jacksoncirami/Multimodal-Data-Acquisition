%% 1. Configuration & Setup
clear; clc;

% UPDATE THIS: Put the exact path to your loose BertecDevice.dll file
bertec_dll_path = 'C:\Users\YOUR_USERNAME\Downloads\BertecDevice.dll'; 

fprintf('Loading Bertec library directly into MATLAB...\n');
try
    % Load the file assembly into MATLAB memory
    asm = NET.addAssembly(bertec_dll_path);
    
    % Get a list of the exact command structures inside your file
    available_classes = cell(asm.Classes);
    
    % AUTOMATIC LINE 15 FIX: Automatically detects the correct spelling 
    if any(contains(available_classes, 'Bertec.Device.DeviceManager'))
        deviceManager = Bertec.Device.DeviceManager();
    elseif any(contains(available_classes, 'Bertec.DeviceManager'))
        deviceManager = Bertec.DeviceManager();
    elseif any(contains(available_classes, 'Bertec.DigitalDeviceManager'))
        deviceManager = Bertec.DigitalDeviceManager();
    elseif any(contains(available_classes, 'Bertec.Device'))
        deviceManager = Bertec.Device(); 
    else
        fprintf('\n--- Found custom naming formats inside file: ---\n');
        disp(available_classes);
        error('Please see the list above to update your initialization block.');
    end
    
    % Complete the native hardware initialization loop
    deviceManager.Initialize();
    fprintf('Bertec hardware initialized successfully via the DLL!\n');
    
catch ME
    error('Could not initialize. Make sure ALL other Bertec apps are closed! Details: %s', ME.message);
end

%% 2. Setup the LSL Network Outlet
fprintf('Loading LSL library...\n');
lib = lsl_loadlib();

% Define stream parameters (6 channels: Fx, Fy, Fz, Mx, My, Mz)
stream_name = 'BertecForcePlate';
stream_type = 'Force';
num_channels = 6; 
sample_rate = 1000; 
source_id = 'Bertec_FP_01';

info = lsl_streaminfo(lib, stream_name, stream_type, num_channels, sample_rate, 'cf_float32', source_id);
outlet = lsl_outlet(info);
fprintf('LSL stream "%s" is now broadcasting.\n', stream_name);

%% 3. Data Streaming Loop
% Create a popup window in MATLAB to catch a keypress to stop the loop safely
stop_fig = figure('Name', 'Stop Bertec Stream', 'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
                  'Position', [100 100 300 100], 'Menu', 'none', 'ToolBar', 'none');
uicontrol('Style', 'text', 'String', 'Press ANY KEY in this window to stop streaming.', ...
          'Position', [20 30 260 40], 'FontSize', 10);

disp('Streaming Bertec data... Select the popup window and press any key to stop.');

try
    while ~strcmp(get(stop_fig, 'Tag'), 'stop')
        
        % Fetch data array directly from the USB-connected device manager
        forceData = deviceManager.GetLatestData();
        
        % If MATLAB receives data, push it out to the LSL network
        if ~isempty(forceData)
            outlet.push_sample(forceData);
        end
        
        pause(0.001); 
    end
catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 4. Clean Up and Close Connections
fprintf('Closing hardware connections...\n');
deviceManager.Close(); 
if ishandle(stop_fig); close(stop_fig); end
disp('Bertec stream closed cleanly.');
