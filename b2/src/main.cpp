#include <Arduino.h>
#include <LED.h>
#include <PushBTN.h>

LED led1(LED_PIN1, LED_ACT1);
LED led2(LED_PIN2, LED_ACT2);

void btnPush();
void btnDoubleClick();
void btnHold();

PushBTN button(BTN_PIN, BTN_ACT, btnPush, btnHold, btnDoubleClick);

int selected = 0;  //led 1 = 0 ; led2 = 1

void setup()
{
    led1.off();
    led2.off();
}

void loop()
{
    led1.loop();
    led2.loop();
    button.loop();
}

void btnPush() {
    if (selected == 0) led1.flip();
    else led2.flip();
}

void btnDoubleClick() {
    selected = 1 - selected; // chuyển LED
}

void btnHold() {
    if (selected == 0) led1.blink(200);
    else led2.blink(200);
}
