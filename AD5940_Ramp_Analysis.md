# Phân Tích Code AD5940_Ramp Example

## 1. Tổng Quan

### 1.1. Giới Thiệu
AD5940_Ramp là một ví dụ về kiểm tra ramping (quét điện áp tuyến tính) cho cảm biến điện hóa sử dụng chip AD5940/AD5941 của Analog Devices. Đây là một AFE (Analog Front End) chính xác cao cho đo trở kháng và ứng dụng điện hóa.

### 1.2. Mục Đích
- Tạo tín hiệu ramp (tăng/giảm tuyến tính) để quét điện áp trên cảm biến điện hóa
- Sử dụng sequencer để tự động hóa việc điều khiển DAC và ADC
- Thu thập dữ liệu điện áp/dòng điện từ cảm biến

### 1.3. Cấu Trúc File
```
AD5940_Ramp/
├── AD5940Main.c       - File chính, cấu hình và khởi động ứng dụng
├── RampTest.c         - Logic xử lý ramp test (930 dòng)
├── RampTest.h         - Header file định nghĩa cấu trúc và API
├── ADICUP3029/        - Project files cho ADICUP3029 board
└── NUCLEO-F411/       - Project files cho STM32 NUCLEO board
```

---

## 2. Phân Tích Chi Tiết Các File

### 2.1. AD5940Main.c - File Chính

#### 2.1.1. Biến Toàn Cục
```c
#define APPBUFF_SIZE 1024
uint32_t AppBuff[APPBUFF_SIZE];  // Buffer lưu dữ liệu từ FIFO
float LFOSCFreq;                  // Tần số LFOSC đã đo
```

#### 2.1.2. Hàm RampShowResult()
**Mục đích:** Xử lý và hiển thị dữ liệu đọc từ AD5940

```c
static int32_t RampShowResult(float *pData, uint32_t DataCount)
{
  static uint32_t index;
  for(int i=0; i<DataCount; i++)
  {
    printf("index:%d, %.3f\n", index++, pData[i]);
  }
  return 0;
}
```

**Lưu ý:** 
- In dữ liệu qua UART (tốc độ hạn chế)
- Có thể bỏ qua một số điểm để tăng tốc (comment dòng i += 10)

#### 2.1.3. Hàm AD5940PlatformCfg()
**Mục đích:** Cấu hình tổng quát cho AD5940

**Các bước cấu hình:**

1. **Reset và khởi tạo:**
```c
AD5940_HWReset();      // Reset phần cứng
AD5940_Initialize();   // Khởi tạo sau khi reset
```

2. **Cấu hình Clock:**
```c
clk_cfg.HFOSCEn = bTRUE;              // Enable HFOSC (16MHz)
clk_cfg.LFOSCEn = bTRUE;              // Enable LFOSC (~32kHz)
clk_cfg.SysClkSrc = SYSCLKSRC_HFOSC;  // Dùng HFOSC cho system clock
clk_cfg.SysClkDiv = SYSCLKDIV_1;      // Không chia tần số
clk_cfg.ADCCLkSrc = ADCCLKSRC_HFOSC;  // ADC dùng HFOSC
```

3. **Cấu hình FIFO:**
```c
fifo_cfg.FIFOEn = bTRUE;
fifo_cfg.FIFOMode = FIFOMODE_FIFO;
fifo_cfg.FIFOSize = FIFOSIZE_2KB;     // 2kB cho FIFO
fifo_cfg.FIFOSrc = FIFOSRC_SINC3;     // Data từ SINC3 filter
fifo_cfg.FIFOThresh = 4;
```

4. **Cấu hình Sequencer:**
```c
seq_cfg.SeqMemSize = SEQMEMSIZE_4KB;  // 4kB SRAM cho sequencer
seq_cfg.SeqBreakEn = bFALSE;
seq_cfg.SeqIgnoreEn = bTRUE;
seq_cfg.SeqEnable = bFALSE;
```

5. **Cấu hình Interrupt:**
```c
AD5940_INTCCfg(AFEINTC_1, AFEINTSRC_ALLINT, bTRUE);
AD5940_INTCCfg(AFEINTC_0, 
               AFEINTSRC_DATAFIFOTHRESH|
               AFEINTSRC_ENDSEQ|
               AFEINTSRC_CUSTOMINT0, bTRUE);
```

6. **Cấu hình GPIO:**
```c
gpio_cfg.FuncSet = GP0_INT|GP1_SLEEP|GP2_SYNC;
// GP0: Interrupt output
// GP1: Sleep state indicator  
// GP2: ADC sampling indicator
```

7. **Đo tần số LFOSC:**
```c
LfoscMeasure.CalDuration = 1000.0;          // 1 giây
LfoscMeasure.SystemClkFreq = 16000000.0f;   // 16MHz
AD5940_LFOSCMeasure(&LfoscMeasure, &LFOSCFreq);
```

#### 2.1.4. Hàm AD5940RampStructInit()
**Mục đích:** Khởi tạo tham số cho ứng dụng Ramp

```c
void AD5940RampStructInit(void)
{
  AppRAMPCfg_Type *pRampCfg;
  AppRAMPGetCfg(&pRampCfg);
  
  // Cấu hình chung
  pRampCfg->SeqStartAddr = 0x10;        // Bắt đầu từ địa chỉ 0x10
  pRampCfg->MaxSeqLen = 1024-0x10;      // Độ dài tối đa
  pRampCfg->RcalVal = 10000.0;          // RCAL = 10kΩ
  pRampCfg->ADCRefVolt = 1820.0f;       // Vref ADC = 1.82V
  pRampCfg->FifoThresh = 480;           // Ngưỡng FIFO
  
  // Tham số tín hiệu Ramp
  pRampCfg->RampStartVolt = -1000.0f;   // Bắt đầu -1V
  pRampCfg->RampPeakVolt = +1000.0f;    // Đỉnh +1V
  pRampCfg->VzeroStart = 1300.0f;       // Vzero bắt đầu 1.3V
  pRampCfg->VzeroPeak = 1300.0f;        // Vzero đỉnh 1.3V
  pRampCfg->StepNumber = 800;           // 800 bước
  pRampCfg->RampDuration = 24*1000;     // 24 giây
  pRampCfg->SampleDelay = 7.0f;         // Delay 7ms
  
  // Cấu hình receive path
  pRampCfg->LPTIARtiaSel = LPTIARTIA_4K;  // RTIA = 4kΩ
  pRampCfg->LPTIARloadSel = LPTIARLOAD_SHORT;
  pRampCfg->AdcPgaGain = ADCPGA_1P5;      // PGA gain 1.5x
}
```

#### 2.1.5. Hàm AD5940_Main()
**Mục đích:** Vòng lặp chính của ứng dụng

```c
void AD5940_Main(void)
{
  uint32_t temp; 
  AppRAMPCfg_Type *pRampCfg;
  
  // Khởi tạo
  AD5940PlatformCfg();
  AD5940RampStructInit();
  AppRAMPInit(AppBuff, APPBUFF_SIZE);
  AppRAMPCtrl(APPCTRL_START, 0);
  
  while(1)
  {
    AppRAMPGetCfg(&pRampCfg);
    
    // Xử lý interrupt từ AD5940
    if(AD5940_GetMCUIntFlag())
    {
      AD5940_ClrMCUIntFlag();
      temp = APPBUFF_SIZE;
      AppRAMPISR(AppBuff, &temp);
      RampShowResult((float*)AppBuff, temp);
    }
    
    // Lặp lại measurement liên tục
    if(pRampCfg->bTestFinished == bTRUE)
    {
      AD5940_Delay10us(200000);  // Delay 2 giây
      pRampCfg->bTestFinished = bFALSE;
      AD5940_SEQCtrlS(bTRUE);
      AppRAMPCtrl(APPCTRL_START, 0);
    }
  }
}
```

---

### 2.2. RampTest.h - Header File

#### 2.2.1. Định Nghĩa Macro
```c
#define ALIGIN_VOLT2LSB     0
#define DAC12BITVOLT_1LSB   (2200.0f/4095)  // ~0.537mV
#define DAC6BITVOLT_1LSB    (DAC12BITVOLT_1LSB*64)  // ~34.4mV
```

#### 2.2.2. Cấu Trúc AppRAMPCfg_Type

**Các tham số cấu hình chung:**
```c
typedef struct
{
  // Tham số chung
  BoolFlag  bParaChanged;
  uint32_t  SeqStartAddr;
  uint32_t  MaxSeqLen;
  float     LFOSCClkFreq;
  float     SysClkFreq;
  float     AdcClkFreq;
  float     RcalVal;
  float     ADCRefVolt;
  BoolFlag  bTestFinished;
  
  // Tham số tín hiệu Ramp
  float     RampStartVolt;    // Điện áp bắt đầu (mV)
  float     RampPeakVolt;     // Điện áp đỉnh (mV)
  float     VzeroStart;       // Vzero bắt đầu (mV)
  float     VzeroPeak;        // Vzero đỉnh (mV)
  uint32_t  StepNumber;       // Số bước (≤ 4095)
  uint32_t  RampDuration;     // Thời gian tổng (ms)
  
  // Cấu hình receive path
  float     SampleDelay;      // Delay giữa DAC update và ADC sample (ms)
  uint32_t  LPTIARtiaSel;     // Chọn RTIA
  uint32_t  LPTIARloadSel;    // Chọn Rload
  float     ExternalRtiaValue;
  uint32_t  AdcPgaGain;
  uint8_t   ADCSinc3Osr;
  uint32_t  FifoThresh;
  
  // Biến private
  BoolFlag  RAMPInited;
  fImpPol_Type RtiaValue;
  SEQInfo_Type InitSeqInfo;
  SEQInfo_Type ADCSeqInfo;
  BoolFlag     bFirstDACSeq;
  SEQInfo_Type DACSeqInfo;
  uint32_t  CurrStepPos;
  float     DACCodePerStep;
  float     CurrRampCode;
  uint32_t  CurrVzeroCode;
  BoolFlag  bDACCodeInc;
  BoolFlag  StopRequired;
  enum _RampState{
    RAMP_STATE0 = 0, 
    RAMP_STATE1, 
    RAMP_STATE2, 
    RAMP_STATE3, 
    RAMP_STATE4, 
    RAMP_STOP
  } RampState;
  BoolFlag  bRampOneDir;
} AppRAMPCfg_Type;
```

#### 2.2.3. API Functions
```c
AD5940Err AppRAMPInit(uint32_t *pBuffer, uint32_t BufferSize);
AD5940Err AppRAMPGetCfg(void *pCfg);
AD5940Err AppRAMPISR(void *pBuff, uint32_t *pCount);
AD5940Err AppRAMPCtrl(uint32_t Command, void *pPara);
```

---

### 2.3. RampTest.c - Logic Chính

#### 2.3.1. Kiến Trúc Tín Hiệu Ramp

**Mô tả tín hiệu:**
```
(Vbias - Vzero):
    RampPeakVolt   -->            /\
                                 /  \
                                /    \
                               /      \
                              /        \
                             /          \
    RampStartVolt   -->     /            \

Vzero:
VzeroStart -->  ______          _____
                      |        |
VzeroPeak  -->        |________|

Vbias:
VbiasPeak  -->       /|   /\   |\
                    / |  /  \  | \
                   /  | /    \ |  \
                  /   |/      \|   \
VbiasStart -->   /    |        |    \

RampState:      S0 | S1  | S2 |S3 |  S4 |
```

**Công thức tính:**
- Vbias = (Vbias - Vzero) + Vzero
- Dòng điện: I = Vcell / Rtia
- Vcell = Vbias - Vzero

#### 2.3.2. Phương Pháp Sequencer

**Phân bổ SRAM (6kB tổng):**
```
|Sequence ID | Address Range  | Usage                    |
|------------|----------------|--------------------------|
|SEQID_3     | 0x0000-0xzzzz | Init sequence            |
|SEQID_2     | 0xzzzz-0xyyyy | ADC control sequence     |
|SEQID_0/1   | 0xyyyy-end    | DAC update (Ping-Pong)   |
```

**Thứ tự chạy Sequencer:**
```
DAC Update:  ↑       ↑       ↑       ↑       ↑       ↑
            SEQ0    SEQ1    SEQ0    SEQ1    SEQ0    SEQ1
               |   /   |   /   |   /   |   /   |   /   |   /
            SEQ2    SEQ2    SEQ2    SEQ2    SEQ2    SEQ2
WuptTrigger ↑  ↑    ↑  ↑    ↑  ↑    ↑  ↑    ↑  ↑    ↑  ↑
Time       |t1| t2 |t1| t2 |t1| t2 |t1| t2 |t1| t2 |t1| t2
```

Trong đó:
- **t1:** SampleDelay - thời gian để DAC ổn định
- **t2:** Thời gian ADC lấy mẫu
- **SEQ0/SEQ1:** Update DAC với điện áp mới (Ping-Pong buffer)
- **SEQ2:** Điều khiển ADC lấy mẫu

#### 2.3.3. Sequencer Command Block

**Block 1 - DAC Update:**
```c
SEQ_WR(REG_AFE_LPDACDAT0, 0x1234);      // Update DAC
SEQ_WAIT(10);                            // Đợi DAC update
SEQ_WR(REG_AFE_SEQ1INFO, NextAddr|SeqLen); // Set next sequence
SEQ_SLP();                               // Sleep
```

**Block 2 - Stop Sequence:**
```c
SEQ_NOP();
SEQ_NOP();
SEQ_NOP();
SEQ_STOP();  // Disable sequencer
```

**Block 3 - Ping-Pong Buffer:**
```c
SEQ_WR(REG_AFE_LPDACDAT0, 0x1234);
SEQ_WAIT(10);
SEQ_WR(REG_AFE_SEQ1INFO, NextAddr|SeqLen);
SEQ_INT0();  // Interrupt để update buffer
```

#### 2.3.4. Hàm AppRAMPCtrl()

**APPCTRL_START:**
```c
case APPCTRL_START:
{
  WUPTCfg_Type wupt_cfg;
  
  // Cấu hình Wakeup Timer
  wupt_cfg.WuptEn = bTRUE;
  wupt_cfg.WuptEndSeq = WUPTENDSEQ_D;
  wupt_cfg.WuptOrder[0] = SEQID_0;  // First: Update DAC
  wupt_cfg.WuptOrder[1] = SEQID_2;  // Second: ADC sample
  wupt_cfg.WuptOrder[2] = SEQID_1;  // Third: Update DAC
  wupt_cfg.WuptOrder[3] = SEQID_2;  // Fourth: ADC sample
  
  // Timing calculation
  wupt_cfg.SeqxWakeupTime[SEQID_2] = 
    (uint32_t)(LFOSCClkFreq * SampleDelay / 1000.0f) - 4 - 2;
  
  wupt_cfg.SeqxWakeupTime[SEQID_0] = 
    (uint32_t)(LFOSCClkFreq * 
               (RampDuration/StepNumber - SampleDelay) / 1000.0f) - 4 - 2;
  
  AD5940_WUPTCfg(&wupt_cfg);
  break;
}
```

---

## 3. Luồng Hoạt Động (Flow)

### 3.1. Khởi Tạo
```
1. AD5940_HWReset()
2. AD5940_Initialize()
3. AD5940PlatformCfg()
   - Configure Clock (HFOSC, LFOSC)
   - Configure FIFO (2kB)
   - Configure Sequencer (4kB)
   - Configure Interrupt
   - Configure GPIO
   - Measure LFOSC frequency
4. AD5940RampStructInit()
   - Set ramp parameters
5. AppRAMPInit()
   - Generate initialization sequence
   - Generate ADC sequence
   - Generate first DAC sequence
6. AppRAMPCtrl(APPCTRL_START)
   - Configure Wakeup Timer
   - Start sequencer
```

### 3.2. Measurement Loop
```
while(1)
{
  1. Check MCU interrupt flag
  2. If interrupt:
     - Clear flag
     - Call AppRAMPISR() to process FIFO data
     - Display results
  3. If test finished:
     - Delay 2 seconds
     - Restart measurement
}
```

### 3.3. Sequencer Execution
```
Wakeup Timer triggers:
1. SEQ0: Update DAC to voltage V[n]
2. Wait t1 (SampleDelay)
3. SEQ2: ADC samples data
4. Wait t2
5. SEQ1: Update DAC to voltage V[n+1]
6. Wait t1
7. SEQ2: ADC samples data
8. Wait t2
9. Repeat until all steps completed
```

---

## 4. Kỹ Thuật Quan Trọng

### 4.1. Ping-Pong Buffer
Do SRAM hạn chế (4kB cho sequencer), không thể lưu tất cả các lệnh cho hàng trăm bước. Giải pháp:
- Sử dụng SEQ0 và SEQ1 luân phiên
- Mỗi sequence tự cập nhật địa chỉ của sequence kế tiếp
- Khi cần, generate interrupt để MCU cập nhật buffer

### 4.2. DAC Code Calculation
```c
// 12-bit DAC: 0-4095 tương ứng 0.2V - 2.2V
// Volt = Code * (2200.0/4095) + 200.0 mV
// Code = (Volt - 200.0) / (2200.0/4095)

DACCodePerStep = (RampPeakVolt - RampStartVolt) / StepNumber;
```

### 4.3. Timing Control
```c
// Tổng thời gian mỗi bước
TimePerStep = RampDuration / StepNumber;

// Thời gian chờ DAC ổn định
SampleDelay = 7.0ms (user defined);

// Thời gian còn lại cho ADC
ADCTime = TimePerStep - SampleDelay;
```

### 4.4. Wakeup Timer Configuration
```c
// LFOSC ~ 32kHz
// WakeupTime tính bằng số clock cycles của LFOSC

WakeupTime_SEQ2 = LFOSCClkFreq * SampleDelay / 1000 - 4 - 2;
WakeupTime_SEQ0 = LFOSCClkFreq * (TimePerStep - SampleDelay) / 1000 - 4 - 2;
```

Trong đó:
- **-4:** Sleep time
- **-2:** Overhead

---

## 5. Ưu Điểm và Hạn Chế

### 5.1. Ưu Điểm
1. **Tự động hóa cao:** Sequencer tự động điều khiển DAC và ADC
2. **Tiết kiệm năng lượng:** Chip sleep giữa các bước
3. **Timing chính xác:** Wakeup Timer đảm bảo timing ổn định
4. **Linh hoạt:** Dễ dàng thay đổi tham số ramp

### 5.2. Hạn Chế
1. **SRAM hạn chế:** Cần ping-pong buffer cho nhiều bước
2. **UART chậm:** In dữ liệu qua UART ảnh hưởng tốc độ
3. **Cần calibration:** ADC và DAC cần calibrate để chính xác

---

## 6. Ứng Dụng

### 6.1. Cyclic Voltammetry (CV)
- Quét điện áp tuyến tính để phân tích phản ứng oxy hóa-khử
- Xác định điện thế oxy hóa-khử của chất

### 6.2. Linear Sweep Voltammetry (LSV)
- Tương tự CV nhưng chỉ quét 1 chiều
- Xác định nồng độ chất phân tích

### 6.3. Electrochemical Sensor Testing
- Kiểm tra đặc tính của cảm biến khí, pH, glucose,...
- Phân tích đáp ứng của cảm biến

---

## 7. Tham Số Cấu Hình Mẫu

```c
// Ví dụ 1: Ramp chậm
RampStartVolt = -1000.0f;   // -1V
RampPeakVolt = +1000.0f;    // +1V  
StepNumber = 800;           // 800 bước
RampDuration = 24000;       // 24 giây
SampleDelay = 7.0f;         // 7ms

// Mỗi bước: 24000/800 = 30ms
// Mỗi bước điện áp: 2000/800 = 2.5mV

// Ví dụ 2: Ramp nhanh
RampStartVolt = -500.0f;    // -0.5V
RampPeakVolt = +500.0f;     // +0.5V
StepNumber = 200;           // 200 bước  
RampDuration = 2000;        // 2 giây
SampleDelay = 2.0f;         // 2ms

// Mỗi bước: 2000/200 = 10ms
// Mỗi bước điện áp: 1000/200 = 5mV
```

---

## 8. Kết Luận

Code AD5940_Ramp là một ví dụ điển hình về cách sử dụng sequencer để tự động hóa phép đo điện hóa. Các kỹ thuật chính bao gồm:

1. **Sequencer architecture:** Sử dụng nhiều sequence phối hợp
2. **Ping-pong buffer:** Tối ưu SRAM hạn chế
3. **Wakeup Timer:** Điều khiển timing chính xác
4. **Low power:** Chip sleep giữa các measurement

Code này có thể được sử dụng làm template cho các ứng dụng electrochemical khác như amperometric sensing, impedance spectroscopy, v.v.

---

## 9. Tài Liệu Tham Khảo

1. [AD5940 Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/AD5940.pdf)
2. [AD5940 Wiki](https://wiki.analog.com/resources/eval/user-guides/ad5940)
3. [AD5940 GitHub Repository](https://github.com/analogdevicesinc/ad5940-examples)
4. [Electrochemical Techniques](https://www.analog.com/en/technical-articles/electrochemical-measurement-techniques.html)
