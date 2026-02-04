# Phân tích mã nguồn AD5940_Ramp từ @analogdevicesinc/ad5940-examples

## Tổng quan

Ví dụ **AD5940_Ramp** là một ứng dụng thử nghiệm điện hóa (electrochemical) sử dụng IC AD5940 của Analog Devices. Mục đích chính là tạo tín hiệu dạng ramp (dốc) và đo dòng điện phản hồi từ cảm biến điện hóa.

**Nguồn:** [GitHub - analogdevicesinc/ad5940-examples](https://github.com/analogdevicesinc/ad5940-examples/tree/main/examples/AD5940_Ramp)

## Cấu trúc file

| File | Mô tả |
|------|-------|
| `AD5940Main.c` | Chương trình chính, cấu hình phần cứng và vòng lặp chính |
| `RampTest.c` | Logic xử lý tín hiệu ramp, quản lý sequencer |
| `RampTest.h` | Header file chứa cấu trúc dữ liệu và định nghĩa |

---

## 1. File AD5940Main.c

### 1.1 Hằng số và biến toàn cục

```c
#define APPBUFF_SIZE 1024
uint32_t AppBuff[APPBUFF_SIZE];  // Buffer lưu trữ dữ liệu từ FIFO
float LFOSCFreq;                 // Tần số LFOSC đo được (xung nhịp nội bộ)
```

### 1.2 Hàm `RampShowResult()`

```c
static int32_t RampShowResult(float *pData, uint32_t DataCount)
{
  static uint32_t index;
  for(int i=0;i<DataCount;i++)
  {
    printf("index:%d, %.3f\n", index++, pData[i]);
  }
  return 0;
}
```

**Chức năng:** In kết quả đo ra UART
- `pData`: Con trỏ đến buffer chứa dữ liệu đã xử lý (đơn vị: µA)
- `DataCount`: Số lượng mẫu có trong buffer
- `index`: Biến static để đánh số thứ tự mẫu

### 1.3 Hàm `AD5940PlatformCfg()`

Đây là hàm cấu hình nền tảng AD5940, thực hiện các bước:

#### Bước 1: Cấu hình Clock
```c
clk_cfg.HFOSCEn = bTRUE;          // Bật High Frequency Oscillator
clk_cfg.HFXTALEn = bFALSE;        // Không dùng crystal ngoài
clk_cfg.LFOSCEn = bTRUE;          // Bật Low Frequency Oscillator (32kHz)
clk_cfg.SysClkSrc = SYSCLKSRC_HFOSC;  // Nguồn clock hệ thống từ HFOSC
clk_cfg.ADCCLkSrc = ADCCLKSRC_HFOSC;  // Nguồn clock ADC từ HFOSC
```

**Giải thích:**
- **HFOSC** (High Frequency Oscillator): 16MHz, dùng cho hệ thống và ADC
- **LFOSC** (Low Frequency Oscillator): ~32kHz, dùng cho Wakeup Timer

#### Bước 2: Cấu hình FIFO và Sequencer
```c
fifo_cfg.FIFOEn = bTRUE;
fifo_cfg.FIFOSize = FIFOSIZE_2KB;    // 2KB cho FIFO
fifo_cfg.FIFOSrc = FIFOSRC_SINC3;    // Nguồn dữ liệu từ bộ lọc SINC3
seq_cfg.SeqMemSize = SEQMEMSIZE_4KB; // 4KB cho Sequencer
```

**Ý nghĩa phân bổ bộ nhớ:**
- Tổng SRAM: 6KB
- FIFO: 2KB (lưu dữ liệu ADC)
- Sequencer: 4KB (lưu lệnh điều khiển)

#### Bước 3: Cấu hình Interrupt
```c
AD5940_INTCCfg(AFEINTC_1, AFEINTSRC_ALLINT, bTRUE);
AD5940_INTCCfg(AFEINTC_0, 
    AFEINTSRC_DATAFIFOTHRESH |  // Ngắt khi FIFO đạt ngưỡng
    AFEINTSRC_ENDSEQ |          // Ngắt khi kết thúc sequence
    AFEINTSRC_CUSTOMINT0,       // Ngắt tùy chỉnh 0
    bTRUE);
```

#### Bước 4: Cấu hình GPIO
```c
gpio_cfg.FuncSet = GP0_INT |     // GPIO0: tín hiệu ngắt
                   GP1_SLEEP |   // GPIO1: trạng thái sleep
                   GP2_SYNC;     // GPIO2: tín hiệu đồng bộ ADC
```

#### Bước 5: Đo tần số LFOSC
```c
LfoscMeasure.CalDuration = 1000.0;           // Thời gian hiệu chuẩn 1000ms
LfoscMeasure.SystemClkFreq = 16000000.0f;    // Clock hệ thống 16MHz
AD5940_LFOSCMeasure(&LfoscMeasure, &LFOSCFreq);
```

**Tại sao phải đo?** LFOSC không chính xác (~32kHz), cần đo để tính toán thời gian chính xác cho Wakeup Timer.

### 1.4 Hàm `AD5940RampStructInit()`

Cấu hình các tham số cho ứng dụng Ramp:

```c
pRampCfg->SeqStartAddr = 0x10;           // Địa chỉ bắt đầu sequence
pRampCfg->RcalVal = 10000.0;             // Điện trở hiệu chuẩn 10kΩ
pRampCfg->ADCRefVolt = 1820.0f;          // Điện áp tham chiếu ADC (mV)

// Tham số tín hiệu Ramp
pRampCfg->RampStartVolt = -1000.0f;      // Điện áp bắt đầu: -1V
pRampCfg->RampPeakVolt = +1000.0f;       // Điện áp đỉnh: +1V
pRampCfg->VzeroStart = 1300.0f;          // Vzero bắt đầu: 1.3V
pRampCfg->VzeroPeak = 1300.0f;           // Vzero đỉnh: 1.3V
pRampCfg->StepNumber = 800;              // Số bước = số mẫu ADC
pRampCfg->RampDuration = 24*1000;        // Thời gian ramp: 24 giây
pRampCfg->SampleDelay = 7.0f;            // Delay lấy mẫu: 7ms

// Cấu hình đường tín hiệu
pRampCfg->LPTIARtiaSel = LPTIARTIA_4K;   // RTIA = 4kΩ
pRampCfg->LPTIARloadSel = LPTIARLOAD_SHORT;
pRampCfg->AdcPgaGain = ADCPGA_1P5;       // Hệ số khuếch đại PGA = 1.5
```

### 1.5 Hàm `AD5940_Main()`

Vòng lặp chính của ứng dụng:

```c
void AD5940_Main(void)
{
  // Khởi tạo
  AD5940PlatformCfg();
  AD5940RampStructInit();
  AppRAMPInit(AppBuff, APPBUFF_SIZE);
  AppRAMPCtrl(APPCTRL_START, 0);

  while(1)
  {
    if(AD5940_GetMCUIntFlag())           // Kiểm tra cờ ngắt
    {
      AD5940_ClrMCUIntFlag();
      temp = APPBUFF_SIZE;
      AppRAMPISR(AppBuff, &temp);        // Xử lý ngắt
      RampShowResult((float*)AppBuff, temp);
    }
    
    // Lặp lại phép đo
    if(pRampCfg->bTestFinished == bTRUE)
    {
      AD5940_Delay10us(200000);          // Delay 2 giây
      pRampCfg->bTestFinished = bFALSE;
      AD5940_SEQCtrlS(bTRUE);
      AppRAMPCtrl(APPCTRL_START, 0);
    }
  }
}
```

---

## 2. File RampTest.h - Cấu trúc dữ liệu

### 2.1 Định nghĩa hằng số DAC

```c
#define DAC12BITVOLT_1LSB   (2200.0f/4095)  // ~0.537mV/LSB cho DAC 12-bit
#define DAC6BITVOLT_1LSB    (DAC12BITVOLT_1LSB*64)  // ~34.4mV/LSB cho DAC 6-bit
```

### 2.2 Cấu trúc `AppRAMPCfg_Type`

```c
typedef struct
{
  // === Cấu hình chung ===
  BoolFlag  bParaChanged;         // Cờ báo tham số đã thay đổi
  uint32_t  SeqStartAddr;         // Địa chỉ bắt đầu sequence trong SRAM
  uint32_t  MaxSeqLen;            // Độ dài tối đa sequence
  
  // === Tham số hệ thống ===
  float     LFOSCClkFreq;         // Tần số LFOSC (Hz)
  float     SysClkFreq;           // Tần số clock hệ thống
  float     AdcClkFreq;           // Tần số clock ADC
  float     RcalVal;              // Giá trị điện trở hiệu chuẩn (Ω)
  float     ADCRefVolt;           // Điện áp tham chiếu ADC (mV)
  BoolFlag  bTestFinished;        // Cờ báo phép đo hoàn thành
  
  // === Tham số tín hiệu Ramp ===
  float     RampStartVolt;        // Điện áp bắt đầu (mV)
  float     RampPeakVolt;         // Điện áp đỉnh (mV)
  float     VzeroStart;           // Vzero bắt đầu (mV)
  float     VzeroPeak;            // Vzero đỉnh (mV)
  uint32_t  StepNumber;           // Số bước (tối đa 4095)
  uint32_t  RampDuration;         // Thời gian ramp (ms)
  
  // === Cấu hình thu nhận ===
  float     SampleDelay;          // Delay giữa DAC update và ADC sample
  uint32_t  LPTIARtiaSel;         // Chọn RTIA
  uint32_t  LPTIARloadSel;        // Chọn Rload
  float     ExternalRtiaValue;    // Giá trị RTIA ngoài (Ω)
  uint32_t  AdcPgaGain;           // Hệ số khuếch đại PGA
  uint8_t   ADCSinc3Osr;          // Oversampling ratio SINC3
  uint32_t  FifoThresh;           // Ngưỡng FIFO
  
  // === Biến nội bộ ===
  BoolFlag  RAMPInited;           // Cờ đã khởi tạo
  fImpPol_Type RtiaValue;         // Giá trị RTIA đã hiệu chuẩn
  SEQInfo_Type InitSeqInfo;       // Thông tin sequence khởi tạo
  SEQInfo_Type ADCSeqInfo;        // Thông tin sequence ADC
  SEQInfo_Type DACSeqInfo;        // Thông tin sequence DAC
  
  // === Biến trạng thái ===
  uint32_t  CurrStepPos;          // Vị trí bước hiện tại
  float     DACCodePerStep;       // Mã DAC mỗi bước
  float     CurrRampCode;         // Mã ramp hiện tại
  uint32_t  CurrVzeroCode;        // Mã Vzero hiện tại
  BoolFlag  bDACCodeInc;          // DAC tăng hay giảm
  BoolFlag  StopRequired;         // Yêu cầu dừng
  
  // State machine
  enum _RampState {
    RAMP_STATE0 = 0,  // Bắt đầu
    RAMP_STATE1,      // Giai đoạn 1
    RAMP_STATE2,      // Giai đoạn 2
    RAMP_STATE3,      // Giai đoạn 3
    RAMP_STATE4,      // Giai đoạn 4
    RAMP_STOP         // Dừng
  } RampState;
  
  BoolFlag  bRampOneDir;          // Ramp một chiều (không quay lại)
} AppRAMPCfg_Type;
```

---

## 3. File RampTest.c - Logic chính

### 3.1 Nguyên lý tín hiệu Ramp

```
Tín hiệu Ramp (Vbias - Vzero):
    RampPeakVolt   -->            /\
                                 /  \
                                /    \
                               /      \
                              /        \
                             /          \
    RampStartVolt   -->     /            \

Tín hiệu Vzero:
    VzeroStart -->  ______          _____
                         |        |
    VzeroPeak  -->       |________|
```

### 3.2 Cơ chế Sequencer

#### Phân bổ SRAM cho Sequencer:

| Sequence ID | Vùng địa chỉ | Chức năng |
|-------------|--------------|-----------|
| SEQID_3 | SeqStartAddr → [init_end] | Sequence khởi tạo |
| SEQID_2 | [init_end] → [adc_end] | Điều khiển ADC |
| SEQID_0/1 | [adc_end] → MaxSeqLen | Cập nhật DAC (ping-pong buffer) |

**Ghi chú:** 
- `SeqStartAddr`: Địa chỉ bắt đầu (thường là 0x10)
- `[init_end]`: Địa chỉ kết thúc = SeqStartAddr + InitSeqInfo.SeqLen
- `[adc_end]`: Địa chỉ kết thúc = [init_end] + ADCSeqInfo.SeqLen

#### Thứ tự thực thi:

```
DAC voltage:
400mV->                               _______
350mV->                       _______/       \_______
300mV->               _______/                       \_________
250mV->       _______/
200mV->    __/
            ↑       ↑       ↑       ↑       ↑       ↑
            SEQ0    SEQ1    SEQ0    SEQ1    SEQ0    SEQ1
               |   /   |   /   |   /   |   /   |   /   |
               SEQ2    SEQ2    SEQ2    SEQ2    SEQ2    SEQ2
WakeupTimer: ↑  ↑    ↑  ↑    ↑  ↑    ↑  ↑    ↑  ↑    ↑  ↑
             |t1| t2 |t1| t2 |t1| t2 |t1| t2 |t1| t2 |t1| t2

t1 = SampleDelay (delay lấy mẫu)
t1 + t2 = RampDuration / StepNumber (thời gian mỗi bước)
```

### 3.3 Hàm `AppRAMPGetCfg()`

```c
AD5940Err AppRAMPGetCfg(void *pCfg)
{
    if(pCfg)
    {
        *(AppRAMPCfg_Type **)pCfg = &AppRAMPCfg;
        return AD5940ERR_OK;
    }
    return AD5940ERR_PARA;
}
```

**Chức năng:** Trả về con trỏ đến cấu trúc cấu hình để user có thể sửa đổi tham số.

### 3.4 Hàm `AppRAMPCtrl()`

```c
AD5940Err AppRAMPCtrl(uint32_t Command, void *pPara)
{
    switch (Command)
    {
        case APPCTRL_START:      // Bắt đầu đo
            // Cấu hình Wakeup Timer
            wupt_cfg.WuptOrder[0] = SEQID_0;  // SEQ0 -> DAC update
            wupt_cfg.WuptOrder[1] = SEQID_2;  // SEQ2 -> ADC sample
            wupt_cfg.WuptOrder[2] = SEQID_1;  // SEQ1 -> DAC update
            wupt_cfg.WuptOrder[3] = SEQID_2;  // SEQ2 -> ADC sample
            
            // Tính thời gian
            wupt_cfg.SeqxWakeupTime[SEQID_2] = 
                (LFOSCFreq * SampleDelay / 1000) - 6;
            wupt_cfg.SeqxWakeupTime[SEQID_0] = 
                (LFOSCFreq * (RampDuration/StepNumber - SampleDelay) / 1000) - 6;
            break;
            
        case APPCTRL_STOPNOW:    // Dừng ngay
            AD5940_WUPTCtrl(bFALSE);
            break;
            
        case APPCTRL_STOPSYNC:   // Dừng đồng bộ
            AppRAMPCfg.StopRequired = bTRUE;
            break;
            
        case APPCTRL_SHUTDOWN:   // Tắt nguồn
            AD5940_ShutDownS();
            break;
    }
}
```

### 3.5 Hàm `AppRAMPSeqInitGen()`

Tạo sequence khởi tạo:

```c
static AD5940Err AppRAMPSeqInitGen(void)
{
    // Cấu hình Reference
    aferef_cfg.HpBandgapEn = bTRUE;     // Bật HP bandgap
    aferef_cfg.LpBandgapEn = bTRUE;     // Bật LP bandgap
    aferef_cfg.LpRefBufEn = bTRUE;      // Bật LP reference buffer
    
    // Cấu hình LP Loop
    lploop_cfg.LpAmpCfg.LpAmpSel = LPAMP0;
    lploop_cfg.LpAmpCfg.LpAmpPwrMod = LPAMPPWR_BOOST3;  // Chế độ boost
    lploop_cfg.LpAmpCfg.LpPaPwrEn = bTRUE;              // Bật PA
    lploop_cfg.LpAmpCfg.LpTiaPwrEn = bTRUE;             // Bật TIA
    lploop_cfg.LpAmpCfg.LpTiaRtia = AppRAMPCfg.LPTIARtiaSel;
    
    // Cấu hình LPDAC
    lploop_cfg.LpDacCfg.LpDacRef = LPDACREF_2P5;        // Reference 2.5V
    lploop_cfg.LpDacCfg.LpDacSrc = LPDACSRC_MMR;        // Nguồn từ thanh ghi
    lploop_cfg.LpDacCfg.LpDacVbiasMux = LPDACVBIAS_12BIT;  // Vbias từ DAC 12-bit
    lploop_cfg.LpDacCfg.LpDacVzeroMux = LPDACVZERO_6BIT;   // Vzero từ DAC 6-bit
    
    // Cấu hình ADC
    dsp_cfg.ADCBaseCfg.ADCMuxN = ADCMUXN_LPTIA0_N;
    dsp_cfg.ADCBaseCfg.ADCMuxP = ADCMUXP_LPTIA0_P;
    dsp_cfg.ADCFilterCfg.ADCRate = ADCRATE_800KHZ;
    dsp_cfg.ADCFilterCfg.BpSinc3 = bFALSE;   // Sử dụng SINC3 filter
}
```

### 3.6 Hàm `AppRAMPSeqADCCtrlGen()`

Tạo sequence điều khiển ADC:

```c
static AD5940Err AppRAMPSeqADCCtrlGen(void)
{
    // Tính số clock chờ
    clks_cal.DataCount = 1;
    clks_cal.DataType = DATATYPE_SINC3;
    AD5940_ClksCalculate(&clks_cal, &WaitClks);
    
    // Tạo sequence
    AD5940_SEQGpioCtrlS(AGPIO_Pin2);              // Đặt GPIO2 = 1 (đang sample)
    AD5940_AFECtrlS(AFECTRL_ADCPWR, bTRUE);       // Bật nguồn ADC
    AD5940_SEQGenInsert(SEQ_WAIT(16 * 250));      // Chờ 250µs
    AD5940_AFECtrlS(AFECTRL_ADCCNV, bTRUE);       // Bắt đầu chuyển đổi
    AD5940_SEQGenInsert(SEQ_WAIT(WaitClks));      // Chờ dữ liệu
    AD5940_AFECtrlS(AFECTRL_ADCPWR|AFECTRL_ADCCNV, bFALSE);  // Tắt ADC
    AD5940_SEQGpioCtrlS(0);                       // GPIO2 = 0
    AD5940_EnterSleepS();                         // Vào chế độ sleep
}
```

### 3.7 Hàm `RampDacRegUpdate()`

Cập nhật mã DAC theo trạng thái:

```c
static AD5940Err RampDacRegUpdate(uint32_t *pDACData)
{
    // State machine cho ramp 2 chiều
    switch(AppRAMPCfg.RampState)
    {
        case RAMP_STATE0:  // Khởi đầu
            CurrVzeroCode = (VzeroStart - 200) / DAC6BITVOLT_1LSB;
            RampState = RAMP_STATE1;
            break;
            
        case RAMP_STATE1:  // Phase 1: Ramp lên đến 1/4
            if(CurrStepPos >= StepNumber / 4)
            {
                RampState = RAMP_STATE2;
                CurrVzeroCode = (VzeroPeak - 200) / DAC6BITVOLT_1LSB;
            }
            break;
            
        case RAMP_STATE2:  // Phase 2: Ramp đến 2/4
            if(CurrStepPos >= StepNumber * 2 / 4)
            {
                RampState = RAMP_STATE3;
                bDACCodeInc = !bDACCodeInc;  // Đảo chiều
            }
            break;
            
        case RAMP_STATE3:  // Phase 3: Ramp xuống đến 3/4
            if(CurrStepPos >= StepNumber * 3 / 4)
            {
                RampState = RAMP_STATE4;
                CurrVzeroCode = (VzeroStart - 200) / DAC6BITVOLT_1LSB;
            }
            break;
            
        case RAMP_STATE4:  // Phase 4: Kết thúc
            if(CurrStepPos >= StepNumber)
                RampState = RAMP_STOP;
            break;
    }
    
    // Tính mã DAC
    CurrStepPos++;
    if(bDACCodeInc)
        CurrRampCode += DACCodePerStep;
    else
        CurrRampCode -= DACCodePerStep;
    
    VbiasCode = VzeroCode * 64 + CurrRampCode;
    
    // Tạo thanh ghi DAC 32-bit:
    // - Bit [17:12]: VzeroCode (6-bit) cho LPDAC 6-bit
    // - Bit [11:0]:  VbiasCode (12-bit) cho LPDAC 12-bit
    *pDACData = (VzeroCode << 12) | VbiasCode;
}
```

### 3.8 Hàm `AppRAMPSeqDACCtrlGen()`

Tạo sequence cập nhật DAC với cơ chế ping-pong buffer:

```c
static AD5940Err AppRAMPSeqDACCtrlGen(void)
{
    // Mỗi bước cần 4 lệnh sequence
    #define SEQLEN_ONESTEP 4L
    
    // Lệnh sequence cho mỗi bước
    SeqCmdBuff[0] = SEQ_WR(REG_AFE_LPDACDAT0, DACData);  // Ghi dữ liệu DAC
    SeqCmdBuff[1] = SEQ_WAIT(10);                         // Chờ DAC ổn định
    SeqCmdBuff[2] = SEQ_WR(REG_AFE_SEQ1INFO, NextAddr);  // Cập nhật địa chỉ SEQ tiếp
    SeqCmdBuff[3] = SEQ_SLP();                           // Vào sleep
    
    // Lệnh cuối cùng: Dừng sequencer
    SeqCmdBuff[0] = SEQ_NOP();
    SeqCmdBuff[1] = SEQ_NOP();
    SeqCmdBuff[2] = SEQ_NOP();
    SeqCmdBuff[3] = SEQ_STOP();
}
```

### 3.9 Hàm `AppRAMPRtiaCal()`

Hiệu chuẩn điện trở RTIA nội:

```c
static AD5940Err AppRAMPRtiaCal(void)
{
    lprtia_cal.LpAmpSel = LPAMP0;
    lprtia_cal.bPolarResult = bTRUE;              // Kết quả dạng Magnitude + Phase
    lprtia_cal.fFreq = 13.317f;                   // Tần số hiệu chuẩn
    lprtia_cal.fRcal = AppRAMPCfg.RcalVal;        // Điện trở chuẩn
    lprtia_cal.LpTiaRtia = AppRAMPCfg.LPTIARtiaSel;
    
    AD5940_LPRtiaCal(&lprtia_cal, &RtiaCalValue);
    AppRAMPCfg.RtiaValue = RtiaCalValue;
}
```

### 3.10 Hàm `AppRAMPDataProcess()`

Xử lý dữ liệu từ ADC:

```c
static int32_t AppRAMPDataProcess(int32_t *const pData, uint32_t *pDataCount)
{
    for(i = 0; i < datacount; i++)
    {
        pData[i] &= 0xffff;  // Lấy 16 bit thấp
        
        // Chuyển đổi mã ADC sang điện áp
        temp = -AD5940_ADCCode2Volt(pData[i], AdcPgaGain, ADCRefVolt);
        
        // Chuyển điện áp sang dòng điện (đơn vị µA)
        pOut[i] = temp / RtiaValue.Magnitude * 1e3f;
    }
}
```

**Công thức:** `I(µA) = V(mV) / Rtia(Ω) × 1000`

### 3.11 Hàm `AppRAMPISR()`

Xử lý ngắt chính:

```c
AD5940Err AppRAMPISR(void *pBuff, uint32_t *pCount)
{
    IntFlag = AD5940_INTCGetFlag(AFEINTC_0);
    
    if(IntFlag & AFEINTSRC_CUSTOMINT0)  // Ngắt yêu cầu cập nhật buffer
    {
        AD5940_INTCClrFlag(AFEINTSRC_CUSTOMINT0);
        AppRAMPSeqDACCtrlGen();  // Tạo sequence DAC mới
    }
    
    if(IntFlag & AFEINTSRC_DATAFIFOTHRESH)  // FIFO đạt ngưỡng
    {
        FifoCnt = AD5940_FIFOGetCnt();
        AD5940_FIFORd(pBuff, FifoCnt);
        AppRAMPDataProcess(pBuff, &FifoCnt);
        *pCount = FifoCnt;
    }
    
    if(IntFlag & AFEINTSRC_ENDSEQ)  // Kết thúc sequence
    {
        FifoCnt = AD5940_FIFOGetCnt();
        AD5940_FIFORd(pBuff, FifoCnt);
        AppRAMPDataProcess(pBuff, &FifoCnt);
        
        AppRAMPCtrl(APPCTRL_STOPNOW, 0);
        
        // Reset để có thể đo lại
        AppRAMPCfg.bTestFinished = bTRUE;
        AppRAMPCfg.RampState = RAMP_STATE0;
        AppRAMPCfg.bFirstDACSeq = bTRUE;
        AppRAMPSeqDACCtrlGen();
    }
}
```

---

## 4. Sơ đồ khối hệ thống

```
+----------------+     +----------------+     +----------------+
|    MCU/Host    | --> |    AD5940      | --> | Electrochemical|
|                | <-- |    IC          | <-- |    Sensor      |
+----------------+     +----------------+     +----------------+
        |                     |
        |    SPI/I2C          |
        |<------------------->|
        |                     |
        |    GPIO/INT         |
        |<------------------->|

AD5940 Nội bộ:
+------------------------------------------------------------------+
|  +----------+    +----------+    +----------+    +----------+    |
|  |  LPDAC   |--->| LP-TIA   |--->|   ADC    |--->|   FIFO   |    |
|  | (Vbias/  |    | (RTIA)   |    | (SINC3)  |    |          |    |
|  |  Vzero)  |    |          |    |          |    |          |    |
|  +----------+    +----------+    +----------+    +----------+    |
|       ^               ^               ^               |          |
|       |               |               |               v          |
|  +----------------------------------------------------------+   |
|  |                    SEQUENCER (4KB SRAM)                   |   |
|  |  SEQ0/SEQ1: DAC control    SEQ2: ADC control              |   |
|  |  SEQ3: Initialization                                      |   |
|  +----------------------------------------------------------+   |
|       ^                                                          |
|       |                                                          |
|  +----------------------------------------------------------+   |
|  |                    WAKEUP TIMER                           |   |
|  |  Triggers: SEQ0 -> SEQ2 -> SEQ1 -> SEQ2 -> ...            |   |
|  +----------------------------------------------------------+   |
+------------------------------------------------------------------+
```

---

## 5. Tóm tắt quy trình hoạt động

1. **Khởi tạo nền tảng:** Cấu hình clock, FIFO, sequencer, GPIO
2. **Đo LFOSC:** Hiệu chuẩn tần số oscillator nội
3. **Cấu hình tham số:** Đặt các thông số ramp, ADC, RTIA
4. **Hiệu chuẩn RTIA:** Đo chính xác giá trị điện trở RTIA
5. **Tạo sequence:** Tạo các lệnh điều khiển DAC và ADC
6. **Bắt đầu đo:** Kích hoạt Wakeup Timer để trigger sequencer
7. **Vòng lặp đo:**
   - Wakeup Timer trigger SEQ0 → cập nhật DAC
   - Chờ SampleDelay
   - Wakeup Timer trigger SEQ2 → lấy mẫu ADC
   - Wakeup Timer trigger SEQ1 → cập nhật DAC tiếp
   - Lặp lại cho đến khi hết StepNumber
8. **Xử lý dữ liệu:** Chuyển đổi mã ADC thành dòng điện (µA)
9. **Kết thúc:** Reset trạng thái, sẵn sàng cho lần đo tiếp

---

## 6. Tài liệu tham khảo

- [AD5940 Datasheet](https://www.analog.com/en/products/ad5940.html)
- [AD5940 Hardware Reference](https://wiki.analog.com/resources/eval/user-guides/ad5940)
- [GitHub Repository](https://github.com/analogdevicesinc/ad5940-examples)
