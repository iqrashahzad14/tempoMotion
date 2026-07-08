clear

%% Load time axis
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/preprocess/sub-001/sub-001_preprocessed.mat')

time = data_clean.time{1};

%% Load decoding results
base = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_tactileFor';

nSub = 6;

for s = 1:nSub
    fname = fullfile(base, ...
        sprintf('sub%03d', s), ...
        'binarydecoding_svm_touch_decoding', ...
        'iter20_pt3', ...
        'acc_libsvm_touch_decoding.mat');

    tmp = load(fname);

    if s == 1
        acc = zeros([size(tmp.acc_comp_iter), nSub]);
        decode_name = tmp.decode_name;
    end

    acc(:,:,:,s) = tmp.acc_comp_iter;
end

% acc size = decoding condition x time x iteration x subject

%% Plot
figure;

for dc = 1:3

    subplot(3,1,dc);

    % average over iterations and subjects
    y = squeeze(mean(mean(acc(dc,:,:,:), 3), 4));

    plot(time, y, 'LineWidth', 1.5);
    hold on;

    yline(0.5, 'k--');   % chance level
    xline(0, 'k-');

    ylim([0.3 0.7]);
    xlabel('Time (s)');
    ylabel('Accuracy');

    title(decode_name{dc}, 'Interpreter', 'none');

    hold off;
end