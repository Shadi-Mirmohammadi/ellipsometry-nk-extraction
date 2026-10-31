# Ellipsometry n, k Extraction

`extract_nk_from_ellipsometry.m` reads an ellipsometry export (for example from J.A. Woollam WVASE) that contains either ε₁ and ε₂ or n and k, and returns:

- `nk_extracted.csv` and `nk_extracted.xlsx` with wavelength (nm), photon energy (eV), n and k
- plots of n and k against wavelength and energy, and the normal-incidence reflectance R(λ)

## Usage

Run the script in MATLAB and pick the export file when asked. It finds the columns by name, so exports with ε₁/ε₂ or n/k both work.

The measurement data is not included.
