% this script is a wrapper that loads some data (or simulates it) and then
% calls the most recent FOOPSI function to infer spike trains and
% parameters

clear, clc,
fname = 'poisson';

% set simulation metadata
T               = 3000;     % # of time steps
V.dt            = 1/200;    % time step size
V.fast_iter_max = 5;        % # iterations of EM to estimate params
V.fast_poiss    = 0;        % whether observations are poisson (1) or gaussian (0)
V.fast_plot     = 1;

% initialize params
P.a     = 8;                % scale
P.b     = 10/P.a;           % bias
tau     = 1;                % decay time constant for each cell
P.gam   = 1-V.dt/tau;       % set gam
P.lam   = 0.3;              % rate

% simulate data
V.n         = poissrnd(P.lam*V.dt*ones(T,1));   % simulate spike train
V.n(V.n>1)  = 1;                                % make only 1 spike per bin
V.C         = filter(1,[1 -P.gam],V.n);         % calcium concentration
V.F = poissrnd(P.a*(V.C+repmat(P.b,T,1))');

figure(1), clf, hold off; plot(V.F+1); hold all; bar(10*V.n), 

save(['../../data/' fname '.mat'],'V','P')

%% infer spike trains and parameters

for q=1
    if q==1, V.fast_poiss=0; else V.fast_poiss=1; end
    [I{q}.n I{q}.P I{q}.V] = fast_oopsi(V.F,V);
end

save(['../../data/' fname '.mat'],'-append','I')

%% plot results

figure(1), clf, hold on
nrows   = 1+length(I);
ncols   = 1;

Pl.g    = [0.75 0.75 0.75];     % gray color
Pl.fs   = 12;                   % font size
Pl.ms   = 5;                    % marker size
Pl.lw   = 1;                    % line width
Pl.n    = V.n; Pl.n(Pl.n==0)=NaN; % true spike train (0's are NaN's so they don't plot)
Pl.shift= .03;
Pl.xlim = [0 T];
Pl.XTick= Pl.xlim(1):round(mean(Pl.xlim)/2):Pl.xlim(2);
Pl.XTickLabel = round((Pl.XTick-min(Pl.XTick))*V.dt*100)/100;

% plot F and n for neurons
subplot(nrows,ncols,1), hold on
plot(V.F,'Color','k','LineWidth',Pl.lw)
axis([0 T 0 max(V.F)])
set(gca,'YTick',[0:10:max(V.F)]);%,'YTickLabel',[])
ylab=ylabel([{'Fluorescence'}; {'(photons/frame)'}],'FontSize',Pl.fs);
set(ylab,'Rotation',0,'HorizontalAlignment','right','verticalalignment','middle')
title('Fluorescence Projection','FontSize',Pl.fs)
set(gca,'XTick',Pl.XTick-min(Pl.XTick),'XTickLabel',[]); %(Pl.XTick-min(Pl.XTick))*V.dt)
% xlabel('Time (sec)','FontSize',Pl.fs)

%% plot inferred spike train
for q=1:length(I)
    subplot(nrows,ncols,1+q)
    hold on
    stem(Pl.n+.03,'LineStyle','none','Marker','v','MarkerEdgeColor',Pl.g,'MarkerFaceColor',Pl.g,'MarkerSize',Pl.ms)
    bar(I{q}.n/max(I{q}.n),'EdgeColor','k','FaceColor','k')
    axis([0 T 0 1+Pl.shift])
    set(gca,'YTick',[0 1],'YTickLabel',[])
    if q==length(I)
        ylab=ylabel('Spike Inference','FontSize',Pl.fs);
        set(ylab,'Rotation',0,'HorizontalAlignment','right','verticalalignment','middle')
        set(gca,'XTick',Pl.XTick,'XTickLabel',(Pl.XTick-min(Pl.XTick))*V.dt)
        xlabel('Time (sec)','FontSize',Pl.fs)
    else
        ylab=ylabel('Spike Inference','FontSize',Pl.fs);
        set(ylab,'Rotation',0,'HorizontalAlignment','right','verticalalignment','middle')
        set(gca,'XTick',Pl.XTick,'XTickLabel',[])
    end
end
%%
% print fig
wh=[7 3];   %width and height
DirName = '../../figs/';
PrintFig(wh,DirName,fname);
