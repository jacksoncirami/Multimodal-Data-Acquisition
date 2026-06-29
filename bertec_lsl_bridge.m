
% 2. Load Bertec SDK
asm = NET.addAssembly('C:\Path\To\BertecDevice.dll'); % <-- UPDATE THIS PATH
deviceManager = Bertec.Device.DeviceManager();
deviceManager.Initialize();

% 3. Setup LSL Outlet
lib = lsl_loadlib();
info = lsl_streaminfo(lib, 'BertecForcePlate', 'Force', 6, 1000, 'cf_float32', 'Bertec_FP_01');
outlet = lsl_outlet(info);

% 4. Stream Loop
disp('Bertec streaming... Press Ctrl+C to stop.');
try
    while true
        forceData = deviceManager.GetLatestData();
        if ~isempty(forceData)
            outlet.push_sample(forceData);
        end
        pause(0.001); 
    end
catch
    deviceManager.Close();
    disp('Bertec connection safely closed.');
end
