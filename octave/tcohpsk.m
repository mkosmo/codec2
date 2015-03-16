% tcohpsk.m
% David Rowe Oct 2014
%
% Octave script that tests the C port of the coherent PSK modem.  This
% script loads the output of unittest/tcohpsk.c and compares it to the
% output of the reference versions of the same functions written in
% Octave.
%
% Ideas:
% [ ] EB/No v BER curves changing Np, freq offset etc
%     + can do these pretty fast in C, if we jave the channel models
%     [ ] better interpolation between two signals
%     [ ] feedback to correct out freq offset est
%     [ ] fading channel

rand('state',1); 
randn('state',1);
graphics_toolkit ("gnuplot");

cohpsk;
autotest;

n = 2000;
frames = 35;
framesize = 160;
foff = 1;

EsNodB = 8;
EsNo = 10^(EsNodB/10);
variance = 1/EsNo;

load ../build_linux/unittest/tcohpsk_out.txt

sim_in = standard_init();
sim_in.framesize        = 160;
sim_in.ldpc_code        = 0;
sim_in.ldpc_code_rate   = 1;
sim_in.Nc               = 4;
sim_in.Rs               = 50;
sim_in.Ns               = 4;
sim_in.Np               = 2;
sim_in.Nchip            = 1;
sim_in.modulation       = 'qpsk';
sim_in.do_write_pilot_file = 0;
sim_in = symbol_rate_init(sim_in);

rand('state',1); 
tx_bits_coh = round(rand(1,framesize*10));
ptx_bits_coh = 1;

tx_bits_log = [];
tx_symb_log = [];
rx_amp_log = [];
rx_phi_log = [];
ch_symb_log = [];
rx_symb_log = [];
rx_bits_log = [];
noise_log = [];
nerr_log = [];

phase = 1;
freq = exp(j*2*pi*foff/sim_in.Rs);

ch_symb = zeros(sim_in.Nsymbrowpilot, sim_in.Nc);

Nerrs = Tbits = 0;

for i=1:frames
  tx_bits = tx_bits_coh(ptx_bits_coh:ptx_bits_coh+framesize-1);
  ptx_bits_coh += framesize;
  if ptx_bits_coh > length(tx_bits_coh)
    ptx_bits_coh = 1;
  end

  tx_bits_log = [tx_bits_log tx_bits];

  [tx_symb tx_bits prev_tx_sym] = bits_to_qpsk_symbols(sim_in, tx_bits, [], []);
  tx_symb_log = [tx_symb_log; tx_symb];

  noise = sqrt(variance*0.5)*(randn(sim_in.Nsymbrowpilot,sim_in.Nc) + j*randn(sim_in.Nsymbrowpilot,sim_in.Nc));
  noise_log = [noise_log; noise];

  for r=1:sim_in.Nsymbrowpilot
    phase = phase*freq;
    ch_symb(r,:) = tx_symb(r,:)*phase + noise(r,:);  
  end
  phase = phase/abs(phase);
  ch_symb_log = [ch_symb_log; ch_symb];

  [rx_symb rx_bits rx_symb_linear amp_linear amp_ phi_ EsNo_ prev_sym_rx sim_in] = qpsk_symbols_to_bits(sim_in, ch_symb, []);
  rx_symb_log = [rx_symb_log; rx_symb];
  rx_amp_log = [rx_amp_log; amp_];
  rx_phi_log = [rx_phi_log; phi_];
  rx_bits_log = [rx_bits_log rx_bits];

  % BER stats

  if i > 2
    error_positions = xor(prev_tx_bits, rx_bits);
    Nerrs  += sum(error_positions);
    nerr_log = [nerr_log sum(error_positions)];
    Tbits += length(error_positions);
  end
  prev_tx_bits = tx_bits;
end

stem_sig_and_error(1, 111, tx_bits_log_c(1:n), tx_bits_log(1:n) - tx_bits_log_c(1:n), 'tx bits', [1 n -1.5 1.5])
stem_sig_and_error(2, 211, real(tx_symb_log_c(1:n)), real(tx_symb_log(1:n) - tx_symb_log_c(1:n)), 'tx symb re', [1 n -1.5 1.5])
stem_sig_and_error(2, 212, imag(tx_symb_log_c(1:n)), imag(tx_symb_log(1:n) - tx_symb_log_c(1:n)), 'tx symb im', [1 n -1.5 1.5])
stem_sig_and_error(3, 211, real(ch_symb_log_c(1:n)), real(ch_symb_log(1:n) - ch_symb_log_c(1:n)), 'ch symb re', [1 n -1.5 1.5])
stem_sig_and_error(3, 212, imag(ch_symb_log_c(1:n)), imag(ch_symb_log(1:n) - ch_symb_log_c(1:n)), 'ch symb im', [1 n -1.5 1.5])
stem_sig_and_error(4, 211, rx_amp_log_c(1:n), rx_amp_log(1:n) - rx_amp_log_c(1:n), 'Amp Est', [1 n -1.5 1.5])
stem_sig_and_error(4, 212, rx_phi_log_c(1:n), rx_phi_log(1:n) - rx_phi_log_c(1:n), 'Phase Est', [1 n -4 4])
stem_sig_and_error(5, 211, real(rx_symb_log_c(1:n)), real(rx_symb_log(1:n) - rx_symb_log_c(1:n)), 'rx symb re', [1 n -1.5 1.5])
stem_sig_and_error(5, 212, imag(rx_symb_log_c(1:n)), imag(rx_symb_log(1:n) - rx_symb_log_c(1:n)), 'rx symb im', [1 n -1.5 1.5])
stem_sig_and_error(6, 111, rx_bits_log_c(1:n), rx_bits_log(1:n) - rx_bits_log_c(1:n), 'rx bits', [1 n -1.5 1.5])

check(tx_bits_log, tx_bits_log_c, 'tx_bits');
check(tx_symb_log, tx_symb_log_c, 'tx_symb');
check(rx_amp_log, rx_amp_log_c, 'rx_amp_log');
check(rx_phi_log, rx_phi_log_c, 'rx_phi_log');
check(rx_symb_log, rx_symb_log_c, 'rx_symb');
check(rx_bits_log, rx_bits_log_c, 'rx_bits');

% Determine bit error rate

sz = length(tx_bits_log_c);
Nerrs_c = sum(xor(tx_bits_log_c(framesize+1:sz-framesize), rx_bits_log_c(2*framesize+1:sz)));
Tbits_c = sz - 2*framesize;
ber_c = Nerrs_c/Tbits_c;
ber = Nerrs/Tbits;
printf("EsNodB: %4.1f ber..: %3.2f Nerrs..: %d Tbits..: %d\n", EsNodB, ber, Nerrs, Tbits);
printf("EsNodB: %4.1f ber_c: %3.2f Nerrs_c: %d Tbits_c: %d\n", EsNodB, ber_c, Nerrs_c, Tbits_c);
 
% C header file of noise samples so C version gives extacly the same results

function write_noise_file(noise_log)

  [m n] = size(noise_log);

  filename = sprintf("../unittest/noise_samples.h");
  f=fopen(filename,"wt");
  fprintf(f,"/* Generated by write_noise_file() Octave function */\n\n");
  fprintf(f,"COMP noise[][PILOTS_NC]={\n");
  for r=1:m
    fprintf(f, "  {");
    for c=1:n-1
      fprintf(f, "  {%f,%f},", real(noise_log(r, c)), imag(noise_log(r, c)));
    end
    if r < m
      fprintf(f, "  {%f,%f}},\n", real(noise_log(r, n)), imag(noise_log(r, n)));
    else
      fprintf(f, "  {%f,%f}}\n};", real(noise_log(r, n)), imag(noise_log(r, n)));
    end
  end

  fclose(f);
endfunction