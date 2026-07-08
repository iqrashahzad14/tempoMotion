%% visualize preprocessed data
clear

%% set paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
preprocDir = fullfile(projectDir, 'outputs', 'preprocess');

subject = {'sub-002'}; % 'sub-002' 'sub-001' has less trials

%%
figDir = '/Users/iqrashahzad/Desktop/eeg/erpFig';
if ~exist(figDir,'dir')
    mkdir(figDir);
end

%% load the preprocessed data, it is in variable data_clean
load(fullfile(preprocDir, subject{1}, [subject{1} '_preprocessed.mat']));
data_ref = data_clean; 

%% visualize mean of all trials

%%
%visual
cfg = [];
cfg.trials = find(ismember(data_ref.trialinfo,11:12));
data_vis  = ft_preprocessing(cfg,data_ref);
tl_vis = ft_timelockanalysis([],data_vis);
figure;
plot(tl_vis.time,tl_vis.avg');
% plot(tl_vis.time,mean(tl_vis.avg)); %to plot mean
yline(0)
xline(0)
title('visual')
saveas(gcf, fullfile(figDir, [subject{1} '_visualErp.png']))

% tactile up
cfg = [];
cfg.trials = find(ismember(data_ref.trialinfo,21:22));
data_tacup  = ft_preprocessing(cfg,data_ref);
tl_tacup = ft_timelockanalysis([],data_tacup);
figure;
plot(tl_tacup.time,tl_tacup.avg');
% ylim([-8 8]);
yline(0)
xline(0)
title('tactile up')
saveas(gcf, fullfile(figDir, [subject{1} '_tactileUpErp.png']))

% tacile down
cfg = [];
cfg.trials = find(ismember(data_ref.trialinfo,31:32));
data_tacdown  = ft_preprocessing(cfg,data_ref);
tl_tacdown = ft_timelockanalysis([],data_tacdown);
figure;
plot(tl_tacdown.time,tl_tacdown.avg(:,:)');
% ylim([-8 8]);
yline(0)
xline(0)
title('tactile down')
saveas(gcf, fullfile(figDir, [subject{1} '_tactileDownErp.png']))
%%
% %%
% figure;
% subplot(2,1,1);
% 
% cfg = [];
% cfg.trials = find(ismember(data_ref.trialinfo,31));
% data_tacup  = ft_preprocessing(cfg,data_ref);
% tl_tacup = ft_timelockanalysis([],data_tacup);
% 
% plot(tl_tacup.time,tl_tacup.avg');
% 
% subplot(2,1,2);
% 
% cfg = [];
% cfg.trials = find(ismember(data_ref.trialinfo,32));
% data_tacup  = ft_preprocessing(cfg,data_ref);
% tl_tacup = ft_timelockanalysis([],data_tacup);
% 
% plot(tl_tacup.time,tl_tacup.avg');


%% layout
% cfg = [];
% % cfg.layout = fullfile(ftpath,'/template/layout/biosemi128.lay');
% cfg.layout = '/Users/iqrashahzad/Documents/MATLAB/fieldtrip/template/layout/biosemi128.lay';
% lay = ft_prepare_layout(cfg);

%% topoplot

% tl_tmp = tl_tacdown;
% tp_pre = 1;
% tp0 = 32;
% tp200 = 116;
% tp100 = 90;
% tp500 = 193;
% tp1000 = 321;
% 
% cfg = [];
% cfg.begsample = tp0;
% cfg.endsample = tp100;%tp0;
% tl_tmp = ft_redefinetrial(cfg,tl_tmp);
% 
% cfg = [];
% cfg.parameter = 'avg';
% cfg.layout = lay;
% 
% figure;
% ft_topoplotER(cfg,tl_tmp);
% colorbar;

% %%
% 
% acc = cat(5,auc_comp_iter1,auc_comp_iter);
% figure;
% subplot(3,1,1);
% plot(data_clean.time{1},mean(mean(mean(acc(:,:,:,1,:),3),1),5));
% hold on;
% plot(data_clean.time{1},zeros(1,size(data_clean.time{1},2))+0.5,'k--');
% hold off;
% subtitle('visual');
% subplot(3,1,2);
% plot(data_clean.time{1},mean(mean(mean(acc(:,:,:,2,:),3),1),5));
% hold on;
% plot(data_clean.time{1},zeros(1,size(data_clean.time{1},2))+0.5,'k--');
% hold off;
% subtitle('tactiledown');
% subplot(3,1,3);
% plot(data_clean.time{1},mean(mean(mean(acc(:,:,:,3,:),3),1),5));
% hold on;
% plot(data_clean.time{1},zeros(1,size(data_clean.time{1},2))+0.5,'k--');
% hold off;
% subtitle('tactileup');
% 
% %%
% 
% figure;plot(data_ref.time{1},mean(mean(mean(auc_comp_iter1(:,:,:,1,:),3),1),5))
% figure;plot(data_ref.time{1},mean(mean(mean(auc_comp_iter1(:,:,:,2,:),3),1),5))
% figure;plot(data_ref.time{1},mean(mean(mean(auc_comp_iter1(:,:,:,3,:),3),1),5))