clear; close all;
addpath('./Theory');

%% Parameters
fs  = 15e3*14*12;                 % Sampling frequency  ����Ƶ�� fs = F*Nfft = (1/deita t) = N/T0
T = 1/fs;
F   = 15e3;                      % Subcarrier spacing (frequency spacing) ���ز���� F
O   = 4;                         % Overlapping factor �ص�����
L   = 24;                         % Number of subcarriers ���ز�����
K   = 30;                         % Number of FBMC symbols in time (each consists of L subcarriers) ʱ���ϵ�FBMC����������ÿ����L�����ز���ɣ�
bit_per_symbol = 4;             %16QAM
M_SNR_dB = [1:5:30];           % Signal-to-Noise Ratio in dB
NrRepetitions = 100;               % Number of Monte Carlo repetition (different channel realizations)      
QAM_ModulationOrder = 16;     
%% Dependent Parameters
dt  = 1/fs;                      % Time between samples ����ʱ��


% We choose the Hermite prototype filter because it is more flexible in terms of overlapping factor. For other pulses, see "A_PrototypeFilters.m"
% See (10) and (11) for the definition of the Hermite prototype filter
% ѡ��Hermite ԭ���˲���
p_Hermite = @(t,T0) ((t<=(O*T0/2))&(t>-(O*T0/2))).* ...
    1/sqrt(T0).*exp(-pi*(t./(T0/sqrt(2))).^2) .* (...
    1.412692577 + ...
    -3.0145e-3 .*...
                ((12+(-48).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^2+16.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^4 ) )+ ...
    -8.8041e-6 .*...
                (1680+(-13440).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^2+13440.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^4+(-3584).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^6+256.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^8 )+ ...
    -2.2611e-9  .*... 
                 (665280+(-7983360).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^2+13305600.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^4+(-7096320).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^6+1520640.* ...
                    (sqrt(2*pi)*(t./(T0/sqrt(2)))).^8+(-135168).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^10+4096.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^12 )+ ...
    -4.4570e-15 .*... 
                 (518918400+(-8302694400).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^2+19372953600.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^4+(-15498362880).* ...
                   (sqrt(2*pi)*(t./(T0/sqrt(2)))).^6+5535129600.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^8+(-984023040).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^10+89456640.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^12+( ...
                   -3932160).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^14+65536.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^16 )+ ...
     1.8633e-16 .*...
                 (670442572800+(-13408851456000).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^2+40226554368000.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^4+( ...
                   -42908324659200).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^6+21454162329600.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^8+(-5721109954560).* ...
                   (sqrt(2*pi)*(t./(T0/sqrt(2)))).^10+866834841600.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^12+(-76205260800).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^14+3810263040.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^16+ ...
                   (-99614720).*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^18+1048576.*(sqrt(2*pi)*(t./(T0/sqrt(2)))).^20 ));
                    
% For OQAM
T0  = 1/F;          % Time-scaling parameter ʱ�����Ų��� ���������ڣ�
T   = T0/2;         % Time spacing ʱ����


% Number of total samples, round due to numerical inaccuracies  �������ֲ�׼ȷ�����µ�����������
N = round((O*T0+T*(K-1))*fs);  %�ܵĲ�������
t = (0:N-1)*dt-O*T0/2; %��ȥ�ص�����ɢʱ��

%% Transmit Matrix G, see (2), (18) and (22)
for l=0:L-1  %���ز�����
    for k=0:K-1 %FBMC��������
        G(:,l+1,k+1)=p_Hermite(t-k*T,T0).*exp(1j*2*pi*l*F*(t-k*T)).*exp(1j*pi/2*(l+k))*sqrt(dt);
    end
end
G=G(:,:);%ÿ����ɢʱ�䷢��12������ ���ز�����*FBMCһ�����ڷ��Ÿ���

% G����FBMC�ĵ��ƾ���
%������������ ���յĽ���ź��� x^ = G'*G*x

D = G'*G;

%% �������ƶ���
QAM = Modulation.SignalConstellation(QAM_ModulationOrder,'QAM');

%% ����FBMC��Ƶ�Ķ���
ChannelEstimation_FBMC = ChannelEstimation.PilotSymbolAidedChannelEstimation(...
    'Diamond',...                           % Pilot pattern
    [...                                    % Matrix that represents the pilot pattern parameters
    24,...                                   % Number of subcarriers
    6; ...                                  % Pilot spacing in the frequency domain
    30,...                                  % Number of FBMC/OFDM Symbols
    8 ...                                   % Pilot spacing in the time domain
    ],...                                   
    'linear'...                             % Interpolation(Extrapolation) method 'linear','spline','FullAverage,'MovingBlockAverage',...
    );

%% �������������Ķ���
%% Imaginary Interference Cancellation Objects                                               % ����Щ���������֮࣬��������Ծͻ���ݸ��Ĳ����ı�
CodingMethod = ChannelEstimation.ImaginaryInterferenceCancellationAtPilotPosition(...
    'Coding', ...                                       % Cancellation method
    ChannelEstimation_FBMC.PilotMatrix, ...             % PilotMatrix
    D, ...                             % Imaginary interference matrix
    16, ...                                             % Cancel 16 closest interferers
    2 ...                                               % Pilot to data power offset
    );

%Ԥ�ȷ������
BER_FBMC = nan(length(M_SNR_dB),NrRepetitions);
BER_FBMC_perfect = nan(length(M_SNR_dB),NrRepetitions);
FBMC_Subcarriers = L;
FBMC_Symbols = K;
%%���濪ʼ
for i_rep = 1:NrRepetitions
    for i_SNR = 1:length(M_SNR_dB)
        SNR_dB = M_SNR_dB(i_SNR);
    %% ��Ƶ����
    Num_PilotSymbols = CodingMethod.NrPilotSymbols;
    %% ����2���Ʊ�����
    Num_DataSymbols = FBMC_Subcarriers*FBMC_Symbols-Num_PilotSymbols;
    BinDataStream_FBMC = randi([0 1],Num_DataSymbols*log2(QAM.ModulationOrder),1);
    
    %% ���ɷ�������
    xD_FBMC = QAM.Bit2Symbol(BinDataStream_FBMC);%QAM���ƺ�ķ������� 
    
    %% ���ɵ�Ƶ����
    
    xP_FBMC = QAM.SymbolMapping(randi(QAM.ModulationOrder,[Num_PilotSymbols 1]));%16����Ƶ����
    xP_FBMC = xP_FBMC./abs(xP_FBMC); %����

    %% ���뵼Ƶ

    %��Ƶλ�þ���
    Pos_Xp = CodingMethod.PilotMatrix;
%     x_FBMC_Cod = reshape(CodingMethod.PrecodingMatrix*[xP_FBMC;xD_FBMC],[FBMC_Subcarriers FBMC_Symbols]);%24x30FBMC���ţ���720�����ţ����ݷ���688����Ƶ����16����704����Ԥ���������˲��ַ�����
    %���ڼ���Ԥ����ķ���
    x_FBMC = nan(FBMC_Subcarriers,FBMC_Symbols);
    x_FBMC(Pos_Xp == 1) = xP_FBMC;
    x_FBMC(Pos_Xp == 0) = xD_FBMC;

    %% ��ʱ����FBMC����
    s_FBMC = G * reshape(x_FBMC,[FBMC_Subcarriers*FBMC_Symbols 1]);
    %% ƽ̹�ŵ�
       h_flat = sqrt(1/2)*(randn+1j*randn);
    %% �ྶ�ŵ��Ľ�ģ�����ж�����Ƶ�Ƶ�����˥���ŵ�
    fd = 100; %������Ƶ��
    r = 6; %�ྶ����
    a = [0.123 0.3 0.4 0.5 0.7 0.8];%�ྶÿ������˥��a
    d = [2 3 4 5 6 13]; %�ྶ���ӳ�tau
    h = zeros(1,FBMC_Symbols);
    hh = [];
        for k = 1:r
            h1 = a(k) * exp(j*((2*pi*T*fd*d(k)/FBMC_Symbols)));
            hh = [hh,h1];
        end
        h(d+1) = hh;%����ÿ������CIR

    r_channel1 = zeros(size(s_FBMC));%ͨ���������ź�
    r_channel2 = zeros(size(s_FBMC));
    r_channel3 = zeros(size(s_FBMC));
    r_channel4 = zeros(size(s_FBMC));
    r_channel5 = zeros(size(s_FBMC));
    r_channel6 = zeros(size(s_FBMC));
    r_channel7 = zeros(size(s_FBMC));

    r_channel1(1+d(1):length(s_FBMC)) = hh(1)*s_FBMC(1:length(s_FBMC)-d(1));
    r_channel2(1+d(2):length(s_FBMC)) = hh(2)*s_FBMC(1:length(s_FBMC)-d(2));
    r_channel3(1+d(3):length(s_FBMC)) = hh(3)*s_FBMC(1:length(s_FBMC)-d(3));
    r_channel4(1+d(4):length(s_FBMC)) = hh(4)*s_FBMC(1:length(s_FBMC)-d(4));
    r_channel5(1+d(5):length(s_FBMC)) = hh(5)*s_FBMC(1:length(s_FBMC)-d(5));
    r_channel6(1+d(6):length(s_FBMC)) = hh(6)*s_FBMC(1:length(s_FBMC)-d(6));

    Rx_FBMC_noNoise = s_FBMC +  r_channel1 +  r_channel2 +  r_channel3 +  r_channel4 +  r_channel5 +  r_channel6; %�ྶ�ŵ��ĵ���
    %Rx_FBMC_noNoise = h_flat*s_FBMC; %ƽ̹���ŵ���ģ
        for SNR_dB_i = M_SNR_dB
            symbol_power = 0;
            symbol_power = [norm(Rx_FBMC_noNoise)]^2/(length(Rx_FBMC_noNoise));%�źŵķ��Ź���
            bit_power = symbol_power/bit_per_symbol;
            noise_power=10*log10((bit_power/(10^(SNR_dB_i/10))));%��������
            noise=wgn(length(Rx_FBMC_noNoise),1,noise_power,'complex');%����GAUSS�������ź�
        end

        Rx_FBMC = Rx_FBMC_noNoise + noise;%ͨ���ྶ�ŵ����Ҽ��������Ľ����ź�
        %Rx_FBMC = Rx_FBMC_noNoise;
        %���ն˽��
        y_FBMC = G' * Rx_FBMC;
        y_FBMC = reshape(y_FBMC,[FBMC_Subcarriers FBMC_Symbols]);
        
        %LS�ŵ�����
        y_FBMC_pilot = y_FBMC(Pos_Xp == 1);%��ȡ��Ƶ
        h_pilot_FBMC = y_FBMC_pilot ./  xP_FBMC ./ sqrt(CodingMethod.PilotToDataPowerOffset);

        %�ŵ���ֵ
        h_ls_FBMC = ChannelEstimation_FBMC.ChannelInterpolation(h_pilot_FBMC);

        %�ŵ�����
        %�������ȡ���Ǳ��������ݷ���
        y_EQ_FBMC = y_FBMC(Pos_Xp == 0) ./ h_ls_FBMC(Pos_Xp == 0);
        

        %%���
        DetectedBitStream_FBMC_ls = QAM.Symbol2Bit(y_EQ_FBMC(:));

        %%����BER
        BER_FBMC_ls(i_SNR,i_rep) = mean(BinDataStream_FBMC ~= DetectedBitStream_FBMC_ls);




    end
    if mod(i_rep,100)==0
        disp([int2str(i_rep/NrRepetitions*100) '%']);
    end

end

%% Plot BER and BEP
figure();
% semilogy(M_SNR_OFDM_dB,mean(BER_FBMC_Aux,2),'red -o');
hold on;

%LS
semilogy(M_SNR_dB,mean(BER_FBMC_ls,2),'blue -x');
xlabel('�����(dB)'); 
ylabel('BER, BEP');