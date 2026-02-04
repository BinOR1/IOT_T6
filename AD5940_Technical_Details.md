# Chi Tiết Kỹ Thuật AD5940_Ramp

## 1. Cấu Trúc Bộ Nhớ AD5940

### 1.1. Tổng Quan Bộ Nhớ
```
Total SRAM: 6kB (6144 bytes)

Phân chia linh hoạt:
Option 1: 2kB FIFO + 4kB Sequencer (dùng cho Ramp)
Option 2: 4kB FIFO + 2kB Sequencer (các ứng dụng khác)

Sequence Memory Layout (với 4kB):
┌─────────────────────────────────┐ 0x0000
│  SEQ3: Initialization           │
│  (~16-32 commands)               │
├─────────────────────────────────┤ 0x0010 - 0x00xx
│  SEQ2: ADC Control               │
│  (~8-16 commands)                │
├─────────────────────────────────┤ 0x00xx - 0x0yyy
│  SEQ0/SEQ1: DAC Update           │
│  (Dynamic, Ping-Pong)            │
│  (Remaining space)               │
└─────────────────────────────────┘ 0x0FFF
```

### 1.2. Sequence Command Size
Mỗi lệnh sequencer = 4 bytes (32-bit)

Ví dụ với 800 bước:
- SEQ0 commands: 800 × 4 commands/step = 3200 commands
- Memory needed: 3200 × 4 bytes = 12.8 kB
- Available: 4 kB → Cần Ping-Pong buffer!

---

## 2. Chi Tiết Tín Hiệu DAC

### 2.1. LPDAC Specifications
```
AD5940 có 2 LPDAC (Low Power DAC):
- LPDAC0: Vbias output
- LPDAC1: Vzero output (reference)

Specifications:
- Resolution: 12-bit (4096 levels)
- Voltage Range: 0.2V - 2.2V (2.0V span)
- 6-bit mode: 64× coarser steps
- Update time: ~few microseconds
```

### 2.2. DAC Code Calculation

**Formula:**
```c
// Từ điện áp sang DAC code
float Volt2DACCode(float voltage_mV)
{
  // voltage_mV: điện áp mong muốn (mV)
  // DAC range: 200mV - 2200mV
  
  if(voltage_mV < 200.0f) voltage_mV = 200.0f;
  if(voltage_mV > 2200.0f) voltage_mV = 2200.0f;
  
  float code = (voltage_mV - 200.0f) * 4095.0f / 2000.0f;
  return code;
}

// Từ DAC code sang điện áp
float DACCode2Volt(uint32_t code)
{
  // code: 0-4095
  float voltage_mV = (float)code * 2000.0f / 4095.0f + 200.0f;
  return voltage_mV;
}
```

**Ví dụ:**
```c
// Tính DAC code cho Vbias
float VbiasStart = 1200.0f;  // 1.2V
float VbiasPeak = 2000.0f;   // 2.0V

uint32_t DACStartCode = Volt2DACCode(VbiasStart);
// = (1200 - 200) * 4095 / 2000 = 2047.5 ≈ 2048

uint32_t DACPeakCode = Volt2DACCode(VbiasPeak);
// = (2000 - 200) * 4095 / 2000 = 3685.5 ≈ 3686

// Increment per step (800 steps)
float DACCodePerStep = (DACPeakCode - DACStartCode) / 800.0f;
// = (3686 - 2048) / 800 = 2.0475
```

### 2.3. 12-bit vs 6-bit Mode

**12-bit mode:**
- Độ phân giải: 2000mV / 4095 = 0.488 mV/LSB
- Sử dụng: Measurement chính xác cao

**6-bit mode:**  
- Độ phân giải: 2000mV / 64 = 31.25 mV/LSB
- Sử dụng: Coarse adjustment, tiết kiệm năng lượng

---

## 3. Chi Tiết ADC Path

### 3.1. Signal Path
```
Sensor → LPTIA → PGA → ADC → SINC3 Filter → FIFO
         (Rtia)  (Gain)      (ΔΣ)   (Decimation)
```

### 3.2. LPTIA (Low Power TIA)
```c
// Transimpedance Amplifier - chuyển dòng thành áp

Available RTIA values:
LPTIARTIA_OPEN    // Open, external Rtia
LPTIARTIA_200R    // 200Ω
LPTIARTIA_1K      // 1kΩ
LPTIARTIA_2K      // 2kΩ
LPTIARTIA_3K      // 3kΩ
LPTIARTIA_4K      // 4kΩ
LPTIARTIA_6K      // 6kΩ
LPTIARTIA_8K      // 8kΩ
LPTIARTIA_10K     // 10kΩ
LPTIARTIA_12K     // 12kΩ
LPTIARTIA_16K     // 16kΩ
LPTIARTIA_20K     // 20kΩ
LPTIARTIA_24K     // 24kΩ
LPTIARTIA_30K     // 30kΩ
LPTIARTIA_32K     // 32kΩ
LPTIARTIA_40K     // 40kΩ
LPTIARTIA_48K     // 48kΩ
LPTIARTIA_64K     // 64kΩ
LPTIARTIA_85K     // 85kΩ
LPTIARTIA_96K     // 96kΩ
LPTIARTIA_100K    // 100kΩ
LPTIARTIA_120K    // 120kΩ
LPTIARTIA_128K    // 128kΩ
LPTIARTIA_160K    // 160kΩ
LPTIARTIA_196K    // 196kΩ
LPTIARTIA_256K    // 256kΩ
LPTIARTIA_512K    // 512kΩ

// Output voltage
Vout = Isensor × Rtia

// Maximum current
Imax = 1.5V / Rtia  // Giới hạn bởi ADC input range
```

### 3.3. PGA (Programmable Gain Amplifier)
```c
Available PGA gains:
ADCPGA_1      // 1×
ADCPGA_1P5    // 1.5×
ADCPGA_2      // 2×
ADCPGA_4      // 4×
ADCPGA_9      // 9×

// Chú ý: PGA output MUST NOT exceed ±1.5V
// Vout_PGA = Vout_TIA × Gain
```

### 3.4. ADC và SINC3 Filter
```c
// ADC: 16-bit Delta-Sigma
// SINC3 filter: Digital low-pass filter

SINC3 OSR options:
ADCSINC3OSR_2    // OSR = 2
ADCSINC3OSR_4    // OSR = 4
ADCSINC3OSR_5    // OSR = 5

// Data rate
DataRate = ADCClkFreq / (4 × OSR)

// Ví dụ: ADCClkFreq = 16MHz, OSR = 4
DataRate = 16000000 / (4 × 4) = 1 MSa/s
```

### 3.5. Current Calculation
```c
// Từ ADC output tính dòng điện

float ADCCode2Current(uint32_t adcCode, 
                      float rtia, 
                      float pgaGain,
                      float adcRefVolt)
{
  // ADC code: 16-bit signed (-32768 to +32767)
  // Convert to voltage
  int16_t signedCode = (int16_t)adcCode;
  float Vadc = (float)signedCode * adcRefVolt / 32768.0f;
  
  // Reverse through PGA
  float Vtia = Vadc / pgaGain;
  
  // Calculate current (I = V / R)
  float current = Vtia / rtia;  // Ampere
  
  return current * 1e9;  // Convert to nA
}

// Ví dụ
uint32_t adcCode = 0x1000;  // 4096
float rtia = 4000.0f;        // 4kΩ
float pgaGain = 1.5f;
float adcRef = 1820.0f;      // 1.82V

float current_nA = ADCCode2Current(adcCode, rtia, pgaGain, adcRef);
// = (4096 * 1.82 / 32768) / 1.5 / 4000 * 1e9
// ≈ 37.9 nA
```

---

## 4. Wakeup Timer Deep Dive

### 4.1. LFOSC Calibration
```c
// LFOSC frequency varies with temperature, voltage
// Typical: 32kHz ± 10%
// Need calibration!

LFOSCMeasure_Type measure;
measure.CalDuration = 1000.0f;      // 1 second calibration
measure.CalSeqAddr = 0;             // Start address for cal sequence
measure.SystemClkFreq = 16000000.0f;// Reference clock (16MHz HFOSC)

float measuredFreq;
AD5940_LFOSCMeasure(&measure, &measuredFreq);
// measuredFreq ≈ 32000.0 Hz (actual value varies)

printf("LFOSC = %.1f Hz\n", measuredFreq);
```

### 4.2. Wakeup Timer Calculation
```c
// WUPT period = (SeqxSleepTime + SeqxWakeupTime + 2) / LFOSCClkFreq

// Ví dụ: SampleDelay = 7ms
float SampleDelay_ms = 7.0f;
float LFOSCClkFreq = 32000.0f;  // Hz

// Tính số LFOSC cycles
uint32_t cycles = (uint32_t)(LFOSCClkFreq * SampleDelay_ms / 1000.0f);
// = 32000 × 7 / 1000 = 224 cycles

// Trừ overhead
uint32_t SeqxSleepTime = 4;
uint32_t SeqxWakeupTime = cycles - SeqxSleepTime - 2;
// = 224 - 4 - 2 = 218

// Actual delay
float actualDelay = (4 + 218 + 2) * 1000.0f / 32000.0f;
// = 224 / 32000 × 1000 = 7.0 ms ✓
```

### 4.3. Wakeup Order
```c
// WUPT can trigger sequences in specific order

WUPTCfg_Type wupt_cfg;
wupt_cfg.WuptOrder[0] = SEQID_0;  // 1st: Update DAC (SEQ0)
wupt_cfg.WuptOrder[1] = SEQID_2;  // 2nd: Sample ADC (SEQ2)
wupt_cfg.WuptOrder[2] = SEQID_1;  // 3rd: Update DAC (SEQ1)
wupt_cfg.WuptOrder[3] = SEQID_2;  // 4th: Sample ADC (SEQ2)

// Pattern repeats: 0→2→1→2→0→2→1→2→...

// Timing
wupt_cfg.SeqxSleepTime[SEQID_0] = 4;
wupt_cfg.SeqxWakeupTime[SEQID_0] = 218;  // 7ms for DAC settle

wupt_cfg.SeqxSleepTime[SEQID_2] = 4;
wupt_cfg.SeqxWakeupTime[SEQID_2] = 718;  // 23ms for next step
```

---

## 5. Sequence Generation Details

### 5.1. Init Sequence (SEQ3)
```c
// Typical init sequence commands:

uint32_t seq_addr = 0x0010;  // Start after LFOSC calibration

// 1. Configure LPTIA
AD5940_SEQGenInsert(seq_addr++, 
    SEQ_WR(REG_AFE_LPTIACONF, value));

// 2. Configure ADC
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_ADCFILTERCON, value));

// 3. Configure PGA
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_ADCCON, value));

// 4. Configure DAC
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_LPDACCON0, value));

// 5. Switch matrix
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_DSWFULLCON, value));

// Total: ~16-32 commands
```

### 5.2. ADC Control Sequence (SEQ2)
```c
// SEQ2: Simple, fixed sequence

uint32_t seq_addr = InitSeqInfo.SeqLen + InitSeqInfo.SeqStartAddr;

// 1. Power on ADC
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_AFECON, BITM_AFE_AFECON_ADCEN));

// 2. Start conversion
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_AFECON, 
           BITM_AFE_AFECON_ADCEN | BITM_AFE_AFECON_ADCCONVEN));

// 3. Wait for conversion (using AFE_WDT)
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WAIT(100));  // Wait ~100 ADC clocks

// 4. Power off ADC
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_AFECON, 0));

// 5. Sleep
AD5940_SEQGenInsert(seq_addr++,
    SEQ_SLP());

// Total: ~8 commands
```

### 5.3. DAC Update Sequence (SEQ0/SEQ1)
```c
// SEQ0/SEQ1: Dynamic, updated in loop

// Current DAC codes
uint32_t VbiasCode = 2048;  // Current Vbias DAC code
uint32_t VzeroCode = 2866;  // Current Vzero DAC code

// Next step address for SEQ1
uint32_t NextSeq1Addr = DACSeqInfo.SeqStartAddr + 4;

// Generate SEQ0 commands
uint32_t seq_addr = DACSeqInfo.SeqStartAddr;

// 1. Update Vbias
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_LPDACDAT0, 
           (VbiasCode << 16) | (0x01 << 12)));

// 2. Update Vzero
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_LPDACDAT1,
           (VzeroCode << 16) | (0x01 << 12)));

// 3. Wait for DAC update
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WAIT(10));

// 4. Update SEQ1 info register (next sequence address)
AD5940_SEQGenInsert(seq_addr++,
    SEQ_WR(REG_AFE_SEQ1INFO,
           (NextSeq1Addr << 16) | 4));  // Addr | Length

// 5. Sleep
AD5940_SEQGenInsert(seq_addr++,
    SEQ_SLP());

// OR for ping-pong buffer update
// 5. Generate interrupt to update buffer
AD5940_SEQGenInsert(seq_addr++,
    SEQ_INT0());

// Total per step: 4-5 commands
```

---

## 6. Interrupt Handling

### 6.1. Interrupt Sources
```c
// AD5940 can generate multiple interrupts:

AFEINTSRC_DATAFIFOTHRESH   // FIFO threshold reached
AFEINTSRC_ENDSEQ          // Sequence ended
AFEINTSRC_CUSTOMINT0      // Custom interrupt 0
AFEINTSRC_CUSTOMINT1      // Custom interrupt 1
AFEINTSRC_GPT0INT_SLPWUT  // Wakeup timer
// ... and more

// Enable interrupts
AD5940_INTCCfg(AFEINTC_0, 
               AFEINTSRC_DATAFIFOTHRESH | 
               AFEINTSRC_ENDSEQ |
               AFEINTSRC_CUSTOMINT0,
               bTRUE);
```

### 6.2. ISR Flow
```c
// In main loop
if(AD5940_GetMCUIntFlag())
{
  AD5940_ClrMCUIntFlag();
  
  // Read interrupt status
  uint32_t intFlag = AD5940_INTCGetFlag(AFEINTC_0);
  
  if(intFlag & AFEINTSRC_DATAFIFOTHRESH)
  {
    // Read FIFO data
    uint32_t fifoCount = AD5940_FIFOGetCnt();
    AD5940_FIFORd(buffer, fifoCount);
    
    // Process data
    ProcessData(buffer, fifoCount);
  }
  
  if(intFlag & AFEINTSRC_CUSTOMINT0)
  {
    // Update ping-pong buffer
    UpdateDACSequence();
  }
  
  if(intFlag & AFEINTSRC_ENDSEQ)
  {
    // Measurement complete
    bTestFinished = bTRUE;
  }
  
  // Clear interrupt
  AD5940_INTCClrFlag(intFlag);
}
```

---

## 7. Điện Hóa Cơ Bản

### 7.1. Three-Electrode System
```
Working Electrode (WE) ←→ Vbias (from LPDAC0)
Reference Electrode (RE) ←→ Vzero (from LPDAC1)  
Counter Electrode (CE) ←→ Connected to maintain current

Sensor current flows: WE → Sensor → RE
LPTIA measures current at WE
```

### 7.2. Cell Voltage
```
Vcell = Vbias - Vzero

Ví dụ:
Vbias = 1500 mV
Vzero = 1300 mV
Vcell = 1500 - 1300 = 200 mV
```

### 7.3. Current Measurement
```
I_sensor = Vcell / Rsensor + I_parasitic

TIA output:
V_TIA = I_sensor × R_TIA

Ví dụ:
I_sensor = 10 µA
R_TIA = 4 kΩ
V_TIA = 10e-6 × 4000 = 40 mV
```

---

## 8. Performance Analysis

### 8.1. Timing Budget (800 steps, 24s)
```
Time per step: 24000ms / 800 = 30ms

Breakdown:
- DAC update: ~10 µs
- DAC settling: 7 ms (SampleDelay)
- ADC conversion: ~100 µs (with OSR=4)
- FIFO write: ~1 µs
- Sleep/wakeup: ~10 µs
- Total active: ~7.11 ms
- Sleep time: 22.89 ms (76% duty cycle)

Power saving: ~3x compared to continuous operation
```

### 8.2. Resolution
```
Voltage resolution:
- DAC: 2000mV / 4095 = 0.488 mV
- Step size (800 steps, 2V range): 2000mV / 800 = 2.5 mV
- Effective: ~5 DAC codes per step

Current resolution (with Rtia = 4kΩ):
- I = V / R
- ΔI = 0.488mV / 4000Ω = 122 nA per DAC LSB

ADC resolution:
- 16-bit: 65536 levels
- Input range: ±1.5V = 3V
- Resolution: 3000mV / 65536 = 0.046 mV
- Much better than DAC!
```

### 8.3. Memory Usage
```
Init Sequence: ~32 commands × 4 bytes = 128 bytes
ADC Sequence: ~8 commands × 4 bytes = 32 bytes
DAC Sequence: 4 commands × 4 bytes × 2 = 32 bytes (per buffer)

For 800 steps:
- Ideal: 800 × 32 = 25.6 kB (not possible!)
- With 4kB SRAM: Can store ~128 steps
- Solution: Ping-pong buffer, update dynamically
- Actual usage: ~2-3 kB continuously
```

---

## 9. Code Optimization Tips

### 9.1. Reduce UART Overhead
```c
// Instead of printing every point:
for(int i=0; i<DataCount; i++)
{
  printf("index:%d, %.3f\n", index++, pData[i]);
}

// Print every 10th point:
for(int i=0; i<DataCount; i+=10)
{
  printf("index:%d, %.3f\n", index+i, pData[i]);
}

// Or batch print:
char buffer[256];
for(int i=0; i<DataCount; i++)
{
  if(i % 10 == 0)
  {
    sprintf(buffer, "i:%d,v:%.3f ", i, pData[i]);
    printf("%s", buffer);
  }
}
printf("\n");
```

### 9.2. FIFO Threshold Optimization
```c
// Small threshold: More frequent interrupts
FifoThresh = 4;  // Interrupt every 4 samples

// Large threshold: Less overhead, more latency
FifoThresh = 480;  // Interrupt every 480 samples

// Optimal: Balance between latency and overhead
// Rule of thumb: 
// Thresh = SampleRate × MaxAcceptableLatency / 2
```

### 9.3. Dynamic Step Adjustment
```c
// For complex waveforms, adjust step size dynamically

if(currentRegion == REGION_STEEP)
{
  StepNumber = 1000;  // More steps in steep region
  DACCodePerStep = smallValue;
}
else
{
  StepNumber = 200;   // Fewer steps in flat region
  DACCodePerStep = largeValue;
}
```

---

## 10. Debugging Tips

### 10.1. Check LFOSC Frequency
```c
printf("LFOSC: %.1f Hz\n", LFOSCFreq);
// Should be ~32000 Hz ± 10%
// If too far off, timing will be wrong!
```

### 10.2. Monitor Sequence Execution
```c
// Add debug interrupts in sequence
SEQ_INT1();  // Generate interrupt for debugging

// In ISR, toggle GPIO
if(intFlag & AFEINTSRC_CUSTOMINT1)
{
  debugPinToggle();
  debugCounter++;
}
```

### 10.3. Verify DAC Output
```c
// Measure actual DAC output voltage
// Connect multimeter to VBIAS pin
// Check if voltage matches expected value

float expectedVbias = DACCode2Volt(VbiasCode);
printf("Expected Vbias: %.1f mV\n", expectedVbias);
// Measure with DMM and compare
```

### 10.4. FIFO Overflow Check
```c
// Check if FIFO overflowed
uint32_t intc1Flag = AD5940_INTCGetFlag(AFEINTC_1);
if(intc1Flag & AFEINTSRC_DATAFIFOOF)
{
  printf("ERROR: FIFO Overflow!\n");
  // Solutions:
  // 1. Increase FIFO threshold
  // 2. Process data faster
  // 3. Reduce sample rate
}
```

---

## 11. Common Issues and Solutions

### 11.1. Noisy Data
**Problem:** ADC readings show high noise

**Solutions:**
1. Increase SINC3 OSR
2. Use averaging filter
3. Check sensor connection
4. Improve PCB layout (separate analog/digital ground)
5. Add capacitor to VBIAS/VZERO outputs

### 11.2. Timing Inaccurate
**Problem:** Ramp duration not as expected

**Solutions:**
1. Verify LFOSC calibration
2. Check WakeupTime calculation
3. Account for overhead (typically 2-4 cycles)
4. Use oscilloscope to measure actual timing

### 11.3. DAC Not Updating
**Problem:** Voltage stays constant

**Solutions:**
1. Check sequence generation
2. Verify DAC enable bit
3. Confirm LPDAC power supply
4. Check switch matrix configuration
5. Measure DAC output with DMM

### 11.4. No Interrupt
**Problem:** MCU interrupt never fires

**Solutions:**
1. Check interrupt enable (INTC0/INTC1)
2. Verify GPIO interrupt connection
3. Check interrupt flag register
4. Confirm interrupt source enable
5. Check MCU interrupt configuration

---

## 12. Tổng Kết

Code AD5940_Ramp thể hiện kỹ thuật lập trình embedded cao cấp với:

1. **Hardware sequencer:** Tự động hóa phép đo
2. **Low power design:** Sleep mode tối ưu năng lượng  
3. **Real-time control:** Wakeup timer chính xác
4. **Memory management:** Ping-pong buffer hiệu quả
5. **Interrupt-driven:** Architecture không blocking

Hiểu rõ các chi tiết này giúp:
- Customize cho ứng dụng riêng
- Debug hiệu quả
- Optimize performance
- Expand sang các phép đo khác (impedance, amperometry, etc.)
