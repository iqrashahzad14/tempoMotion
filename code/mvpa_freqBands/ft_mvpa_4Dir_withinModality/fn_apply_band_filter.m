function data_band = fn_apply_band_filter(data_in, band)
% FN_APPLY_BAND_FILTER Band-limits an already-epoched FieldTrip raw data
% structure to isolate one of five signal variants used by the
% the ft_mvpa_*_subject.m script in this folder:
%
%   theta / alpha / beta / gamma - bandpass filter + Hilbert amplitude,
%     squared to give instantaneous power (matches Bae & Luck 2019's
%     alpha-power extraction; band edges from Wang et al. 2024: theta
%     4-7, alpha 8-13, beta 14-30, gamma 31-45 Hz).
%   sustainedERP - low-pass filter at 6 Hz on the raw voltage (Bae & Luck
%     2019), isolating the slow phase-locked ERP from any oscillatory
%     content.
%
% band is a struct with fields .name, .freq ([lo hi], or [NaN cutoff] for
% low-pass-only), .type ('power' or 'voltage').

cfg = [];
if strcmp(band.type, 'power')
    cfg.bpfilter = 'yes';
    cfg.bpfreq   = band.freq;
    cfg.hilbert  = 'abs';
    data_band = ft_preprocessing(cfg, data_in);
    for i = 1:numel(data_band.trial)
        data_band.trial{i} = data_band.trial{i} .^ 2; % power = amplitude^2
    end
else
    cfg.lpfilter = 'yes';
    cfg.lpfreq   = band.freq(2);
    data_band = ft_preprocessing(cfg, data_in);
end

end
