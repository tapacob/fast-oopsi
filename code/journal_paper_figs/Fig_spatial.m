% this script generates a simulation of a movie containing a single cell
% using the following generative model:
%
% F_t = \sum_i a_i*C_{i,t} + b + sig*eps_t, eps_t ~ N(0,I)
% C_{i,t} = gam*C_{i,t-1} + n_{i,t},      n_{i,t} ~ Poisson(lam_i*dt)
%
% where ai,b,I are p-by-q matrices.
% we let b=0 and ai be the difference of gaussians (yielding a zero mean
% matrix)
%

clear, clc

% 1) generate spatial filters

% % stuff required for each spatial filter
Nc      = 1;                                % # of cells in the ROI
neur_w  = 10;                               % width per neuron
width   = 10;                               % width of frame (pixels)
height  = Nc*neur_w;                        % height of frame (pixels)
Npixs   = width*height;                     % # pixels in ROI
x       = linspace(-5,5,height);
y       = linspace(-5,5,width);
[X,Y]   = meshgrid(x,y);
g1      = zeros(Npixs,Nc);
g2      = 0*g1;
Sigma1  = diag([1,1])*2;                    % var of positive gaussian
Sigma2  = diag([1,1])*4;                    % var of negative gaussian
mu      = [0 0]; %[1 1]'*linspace(-2,2,Nc);         % means of gaussians for each cell (distributed across pixel space)
w       = Nc:-1:1;                          % weights of each filter

% spatial filter
for i=1:Nc
    g1(:,i)  = w(i)*mvnpdf([X(:) Y(:)],mu(:,i)',Sigma1);
    g2(:,i)  = w(i)*mvnpdf([X(:) Y(:)],mu(:,i)',Sigma2);
end

% 2) set simulation metadata
Sim.T       = 600;                              % # of time steps
Sim.dt      = 0.005;                            % time step size
Sim.MaxIter = 0;                                % # iterations of EM to estimate params
Sim.Np      = Npixs;                            % # of pixels in each image
Sim.w       = width;                            % width of frame (pixels)
Sim.h       = height;                           % height of frame (pixels)
Sim.Nc      = Nc;                               % # cells
Sim.plot    = 0;                                % whether to plot filter with each iteration

% 3) initialize params
for i=1:Sim.Nc
    P.a(:,i)=g1(:,i)-0.5*g2(:,i);
end
P.b     = 0*P.a(:,1);                           % baseline is zero

P.sig   = 0.01;                                 % stan dev of noise (indep for each pixel)
C_0     = 0;                                    % initial calcium
tau     = round(100*rand(Sim.Nc,1))/100+0.05;   % decay time constant for each cell
P.gam   = 1-Sim.dt./tau(1:Sim.Nc);
P.lam   = 5;%round(10*rand(Sim.Nc,1))+5;           % rate-ish, ie, lam*dt=# spikes per second

% 3) simulate data
n=zeros(Sim.T,Sim.Nc);
C=n;
for i=1:Sim.Nc
    n(1,i)      = C_0;
    n(2:end,i)  = poissrnd(P.lam(i)*Sim.dt*ones(Sim.T-1,1));    % simulate spike train
    C(:,i)      = filter(1,[1 -P.gam(i)],n(:,i));               % calcium concentration
end
Z = 0*n(:,1);
F = C*P.a' + (1+Z)*P.b'+P.sig*randn(Sim.T,Npixs);               % fluorescence

%% 4) other stuff

MakMov  = 1;
% make movie of raw data
if MakMov==1
    for i=1:Sim.T
        if i==1, mod='overwrite'; else mod='append'; end
        imwrite(reshape(F(i,:),width,height),'spatial_Mov.tif','tif','Compression','none','WriteMode',mod)
    end
end

GetROI  = 0;
fnum    = 0;

if GetROI
    figure(100); clf,imagesc(reshape(sum(g1-g2,2),width,height))
    for i=1:Nc
        [x y]   = ginput(4);
        ROWS    = [round(mean(y(1:2))) round(mean(y(3:4)))];                              % define ROI
        COLS    = [round(mean(x([1 4]))) round(mean(x(2:3)))];
        COLS1{i}=COLS;
        ROWS1{i}=ROWS;
        save('ROIs','ROWS1','COLS1')
    end
else
    load ROIs
end


%% end-1) infer spike train using various approaches
qs=1:2;%:6;%[1 2 3];
MaxIter=10;
for q=qs
    GG=F; Tim=Sim;
    %     if q==1,                        % estimate spatial filter from real spikes
    %         SpikeFilters;
    %     elseif q==3                     % denoising using SVD of an ROI around each cell, and using first SVD's as filters
    %         ROI_SVD_Filters;
    %     elseif q==4                     % denoising using mean of an ROI around each cell
    %         ROI_mean_Filters;
    %     elseif q==6                     % infer spikes from d-r'ed data
    %         d_r_smoother_Filter;
    if q==1,
        Phat{q}=P;
        I{q}.label='True Filter';
    elseif q==2,
        Phat{q}=P;
        Phat{q}.a=0*P.a+1;
        I{q}.label='Mean Filter';
    end
    display(I{q}.label)
    [I{q}.n I{q}.P] = FOOPSI2_59(GG,Phat{q},Tim);
end

%% end) plot results
clear Pl
nrows   = 3+Nc;                                  % set number of rows
ncols   = 2;
h       = zeros(nrows,1);
Pl.xlims= [5 Sim.T-5];                            % time steps to plot
Pl.nticks=5;                                    % number of ticks along x-axis
Pl.n    = double(n); Pl.n(Pl.n==0)=NaN;         % store spike train for plotting
Pl      = PlotParams(Pl);                       % generate a number of other parameters for plotting
Pl.vs   = 2;
Pl.colors(1,:) = [0 0 0];
Pl.colors(2,:) = Pl.gray;
Pl.colors(3,:) = [.5 0 0];
Pl.Nc   = Sim.Nc;
Pl.XTicks=100:100:400;

% % movie slices
fnum = figure(1); clf,
% i=1; h(i) = subplot(nrows,ncols,1:4);
% v=reshape(F',width,height,Sim.T);
% vv=v(:,:,100:20:Sim.T);
% [XX,YY,ZZ] = meshgrid(x,y,1:size(vv,3));
% inc=5;
% xslice = []; yslice = []; zslice = 1:inc:inc^2; %100:200:Sim.T;
% hh = slice(XX,YY,ZZ,vv,xslice,yslice,zslice);
% rotate(hh,[1 0 1],90)
% colormap gray
% set(gca,'XTick',[-10:inc:inc^2],'XTickLabel',[100:100:Sim.T]*Sim.dt,'FontSize',Pl.fs)
% set(gca,'YTick',[],'FontSize',Pl.fs)
% set(gca,'ZTick',[],'FontSize',Pl.fs)
% set(gca,'XColor',[0 0 0],'YColor',[1 1 1],'ZColor',[1 1 1])
% axis tight
% box off
% grid off
% zlab=zlabel([{'Movie'}; {'Frames'}]);
% set(zlab,'Rotation',0,'HorizontalAlignment','right','verticalalignment','middle','Color','k')


movieslices=[];
Nframes=length(Pl.XTicks);
% frames=round(linspace(1,Sim.T,Nframes));
for i=1:Nframes
    if i<Nframes
        temp=[reshape(GG(Pl.XTicks(i),:),Sim.w,Sim.h); 0.05*ones(Sim.h,1)'];
    else 
        temp=reshape(GG(Pl.XTicks(i),:),Sim.w,Sim.h);
    end
    movieslices=[movieslices; temp];
end
subplot(nrows,ncols,1:4)
imagesc(movieslices'), colormap('gray')
set(gca,'Xtick',[6:Sim.h+1:Nframes*Sim.h],'XTickLabel',Pl.XTicks)
set(gca,'YTick',[])
ylab=ylabel([{'Image'}; {'Frames'}],'FontSize',Pl.fs);
set(ylab,'Rotation',0,'HorizontalAlignment','right','verticalalignment','middle')

for q=qs
    i=q+3;
    % plot fluorescence data
    i=i+1; h(i) = subplot(nrows,ncols,i);
    if q==1,
        title([{'Optimal Projection'}],'FontSize',14);
        Pl.label = 'Fluorescence';
    else
        title([{'Mean Projection'}],'FontSize',14)
        Pl.label = [];
    end
    Pl.color = 'k';
    Plot_nX(Pl,F*Phat{q}.a);

    % plot inferred spike trains
    if q==1, Pl.label = [{'Fast'}; {'Filter'}];
    else Pl.label=[]; end
    i=i+2; h(i) = subplot(nrows,ncols,i);
    Pl.col(2,:)=[0 0 0];
    Pl.gray=[.5 .5 .5];
    hold on
    Plot_n_MAP(Pl,I{q}.n);

    % set xlabel stuff
    subplot(nrows,ncols,i)
    set(gca,'XTick',Pl.XTicks,'XTickLabel',Pl.XTicks*Sim.dt,'FontSize',Pl.fs)
    xlabel('Time (sec)','FontSize',Pl.fs)
    %     linkaxes(h,'x')
end

% print fig
wh=[7 5];   %width and height
set(gcf,'PaperSize',wh,'PaperPosition',[0 0 wh],'Color','w');
FigName = '../../docs/journal_paper/figs/spatial';
print('-depsc',FigName)
print('-dpdf',FigName)
