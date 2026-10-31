%% extract_nk_from_ellipsometry.m
% PURPOSE:
%   Extract real refractive index n(λ) (and extinction k(λ)) from an
%   ellipsometry export file that contains either:
%     (A) epsilon1, epsilon2   OR
%     (B) n, k
%
% WHAT YOU GET:
%   - nk_extracted.csv   with columns: lambda_nm, E_eV, n, k
%   - nk_extracted.xlsx  same
%   - Plots of n and k vs wavelength/energy + reflectance R(λ)
%
% Run it in MATLAB (F5) and pick the export file when asked.

clear; clc; close all;

fprintf('\n=== Extract n,k from ellipsometry export ===\n');
fprintf('PWD: %s\n', pwd);

hc_eVnm = 1239.841984;   % eV*nm

%% ====== PICK FILE (EASIEST + avoids path issues) =======================
[file, path] = uigetfile({'*.xlsx;*.xls;*.csv','Ellipsometry export (*.xlsx, *.csv)'}, ...
                         'Select ellipsometry export');
if isequal(file,0)
    error('No file selected.');
end
infile = fullfile(path, file);
fprintf('Selected: %s\n', infile);

%% ====== READ TABLE ======================================================
[~,~,ext] = fileparts(infile);
ext = lower(ext);

if any(strcmp(ext, {'.xlsx','.xls'}))
    % Read first sheet by default. If your data is not in sheet 1, change this.
    sheet = 1;
    opts = detectImportOptions(infile, 'Sheet', sheet);
    T = readtable(infile, opts);
else
    opts = detectImportOptions(infile);
    T = readtable(infile, opts);
end

if isempty(T) || width(T) < 2
    error('Table is empty or has <2 columns. Check your export.');
end

fprintf('Loaded table: %d rows x %d cols\n', height(T), width(T));
% Uncomment if you want to see raw column names:
% disp(T.Properties.VariableNames);

%% ====== NORMALIZE COLUMN NAMES FOR ROBUST MATCHING =====================
vars_raw = T.Properties.VariableNames;
vars = lower(regexprep(vars_raw, '[^a-z0-9]+', ''));  % only letters+digits

% helper: find a column index by list of candidate normalized names
findcol = @(cands) find(ismember(vars, cands), 1, 'first');

%% ====== FIND AXIS COLUMN: wavelength (nm) or energy (eV) ===============
iLam = findcol({'lambda','lambdanm','wavelength','wavelengthnm','nm'});
iE   = findcol({'e','ev','energy','energyev'});

% If not found, assume first column is the axis
if isempty(iLam) && isempty(iE)
    iAxis = 1;
else
    iAxis = iLam;
    if isempty(iAxis), iAxis = iE; end
end

axisVal = T{:, iAxis};
axisVal = axisVal(:);

% Decide whether axis is energy (eV) or wavelength (nm)
if median(axisVal, 'omitnan') < 50
    E_eV = axisVal;
    lambda_nm = hc_eVnm ./ E_eV;
    axisType = 'Energy (eV)';
else
    lambda_nm = axisVal;
    E_eV = hc_eVnm ./ lambda_nm;
    axisType = 'Wavelength (nm)';
end

fprintf('Axis detected as: %s (using column "%s")\n', axisType, vars_raw{iAxis});

%% ====== FIND DATA COLUMNS: eps1/eps2 or n/k =============================
iEps1 = findcol({'eps1','epsilon1','e1','varepsilon1','dielectric1','realepsilon','realepsilon'});
iEps2 = findcol({'eps2','epsilon2','e2','varepsilon2','dielectric2','imagepsilon','imepsilon','imaginaryepsilon'});

iN = findcol({'n','refractiveindex','indexn','realn'});
iK = findcol({'k','extinctioncoefficient','indexk','imagk','extinction'});

have_eps = ~isempty(iEps1) && ~isempty(iEps2);
have_nk  = ~isempty(iN);

if ~(have_eps || have_nk)
    fprintf('\nI could NOT find eps1/eps2 or n in your columns.\n');
    fprintf('Here are the normalized column names MATLAB sees:\n');
    disp(vars');
    error('Rename/export your columns to include (eps1, eps2) or (n, k).');
end

%% ====== EXTRACT / COMPUTE n,k ==========================================
if have_nk
    n = T{:, iN}; n = n(:);

    if ~isempty(iK)
        k = T{:, iK}; k = k(:);
    else
        k = zeros(size(n));
        warning('Found n but not k. Setting k=0.');
    end

    src = sprintf('Using n/k columns ("%s", "%s")', vars_raw{iN}, tern(~isempty(iK), vars_raw{iK}, 'k=0'));
else
    eps1 = T{:, iEps1}; eps1 = eps1(:);
    eps2 = T{:, iEps2}; eps2 = eps2(:);

    % Convert epsilon -> n,k (always real, nonnegative k)
    abse = sqrt(eps1.^2 + eps2.^2);
    n = sqrt(max((abse + eps1)/2, 0));
    k = sqrt(max((abse - eps1)/2, 0));

    src = sprintf('Computed n,k from eps1/eps2 columns ("%s", "%s")', vars_raw{iEps1}, vars_raw{iEps2});
end

fprintf('%s\n', src);

%% ====== CLEAN + SORT ====================================================
good = isfinite(lambda_nm) & isfinite(E_eV) & isfinite(n) & isfinite(k);
lambda_nm = lambda_nm(good);
E_eV      = E_eV(good);
n         = n(good);
k         = k(good);

[lambda_nm, idx] = sort(lambda_nm, 'ascend');
E_eV = E_eV(idx);
n    = n(idx);
k    = k(idx);

fprintf('After cleaning: %d points\n', numel(lambda_nm));
fprintf('n range: [%.3f, %.3f],  k range: [%.3g, %.3g]\n', min(n), max(n), min(k), max(k));

%% ====== SAVE OUTPUT =====================================================
out = table(lambda_nm, E_eV, n, k, ...
    'VariableNames', {'lambda_nm','E_eV','n','k'});

writetable(out, 'nk_extracted.csv');
writetable(out, 'nk_extracted.xlsx');
fprintf('Saved: nk_extracted.csv and nk_extracted.xlsx\n');

%% ====== PLOTS (FORCE VISIBLE) ==========================================
fig1 = figure('Color','w','Visible','on'); box on; grid on;
plot(lambda_nm, n, 'LineWidth', 1.5);
xlabel('Wavelength (nm)'); ylabel('n');
title('Refractive index n(\lambda) from ellipsometry');
drawnow;

fig2 = figure('Color','w','Visible','on'); box on; grid on;
plot(lambda_nm, k, 'LineWidth', 1.5);
xlabel('Wavelength (nm)'); ylabel('k');
title('Extinction coefficient k(\lambda) from ellipsometry');
drawnow;

fig3 = figure('Color','w','Visible','on'); box on; grid on;
plot(E_eV, n, 'LineWidth', 1.5);
xlabel('Energy (eV)'); ylabel('n');
title('n(E) from ellipsometry');
drawnow;

fig4 = figure('Color','w','Visible','on'); box on; grid on;
plot(E_eV, k, 'LineWidth', 1.5);
xlabel('Energy (eV)'); ylabel('k');
title('k(E) from ellipsometry');
drawnow;

%% ====== OPTIONAL: REFLECTANCE PER SURFACE (NORMAL INCIDENCE) ===========
R = ((n-1).^2 + k.^2) ./ ((n+1).^2 + k.^2);   % per surface
fig5 = figure('Color','w','Visible','on'); box on; grid on;
plot(lambda_nm, R, 'LineWidth', 1.5);
xlabel('Wavelength (nm)'); ylabel('R');
title('Normal-incidence reflectance per surface');
drawnow;

fprintf('Figures created: %d\n', numel(get(0,'Children')));
fprintf('=== Done ===\n');

%% ===================== LOCAL SMALL HELPER ==============================
function s = tern(cond, a, b)
% ternary helper for strings
if cond, s = a; else, s = b; end
end
