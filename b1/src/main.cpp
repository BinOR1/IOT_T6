#include <Arduino.h>
#include <LED.h>
#include <OneButton.h>

LED led(LED_PIN, LED_ACT);

void btnPush();
void btn_doubleclick();
OneButton button(BTN_PIN, !BTN_ACT);

void setup()
{
    led.off();
    button.attachClick(btnPush);
    button.attachDoubleClick(btn_doubleclick);   // nhận ấn 2 lần = blink

    button.setClickMs(500);           // sau 500ms k nhấn 2 lần thì là singleclick
    button.setDebounceMs(50);      // Thời gian chống dội (ms)
}

void loop()
{
    led.loop();
    button.tick();
}

void btnPush()
{
    led.flip();
}

void btn_doubleclick()
{
    led.blink(200);
}