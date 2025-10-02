/***
 * Buttons library for Arduino
 * Author: Nguyen Anh Tuan
 * Version: 2.1 (Mar. 2023) 
 * 
 ***/

#pragma once

#include <Arduino.h>

class PushBTN {
public:
    PushBTN(const byte pin, const bool push, void (&pushCallback)(), 
                        const int debounceTime=5);
                        
    PushBTN(const byte pin, const bool push, void (&pushCallback)(), void (&holdCallback)(), 
                        const int holdTime=2000, 
                        const int debounceTime=5);

    PushBTN(const byte pin, const bool push, void (&pushCallback)(), void (&holdCallback)(),
                        void (&doubleClickCallback)(), 
                        const int doubleClickTime=300,
                        const int holdTime=2000, 
                        const int debounceTime=5);
    void loop();

private:
    const byte _pin;
    const bool _active; // LOW or HIGH
    std::function<void()> _pushCallback{ [](){} };
    std::function<void()> _holdCallback{ [](){} };
    std::function<void()> _doubleClickCallback{ [](){} };

    unsigned long holdTimer = 0;
    unsigned long doubleClickTimer = 0;
    const unsigned int _holdTime = 2000; // default 2000ms = 2s.
    const unsigned int _doubleClickTime = 300; // default 300ms
    const unsigned int _debounceTime = 5;

    byte clickCount = 0; // Đếm số lần click

    enum States {
        RELEASE      = 0,
        PUSH_WAIT    = 1,
        HOLD_WAIT    = 2,
        PUSH         = 3,
        HOLD         = 4,
        RELEASE_WAIT = 5,
        DOUBLE_CLICK_WAIT = 6,
        DOUBLE_CLICK   = 7,
    } state = RELEASE;
};


/***** Implementation: *****/

PushBTN::PushBTN(const byte pin, const bool active, void (&pushCallback)(), 
                const int debounceTime)

    : _pin(pin), _active(active), 
      _pushCallback(pushCallback),
      _debounceTime(debounceTime)
{
    if (active == LOW)
        pinMode(_pin, INPUT_PULLUP);
    else
        pinMode(_pin, INPUT);
}

PushBTN::PushBTN(const byte pin, const bool active, void (&pushCallback)(), 
                void (&holdCallback)(), const int holdTime, 
                const int debounceTime)
                
    : _pin(pin), _active(active), 
      _pushCallback(pushCallback), 
      _holdCallback(holdCallback), 
      _holdTime(holdTime),
      _debounceTime(debounceTime) 
{
    if (active == LOW)
        pinMode(_pin, INPUT_PULLUP);
    else
        pinMode(_pin, INPUT);
}

PushBTN::PushBTN(const byte pin, const bool active, 
                void (&pushCallback)(), 
                void (&holdCallback)(), 
                void (&doubleClickCallback)(),
                const int doubleClickTime,
                const int holdTime, 
                const int debounceTime)

    : _pin(pin), _active(active), 
      _pushCallback(pushCallback),
      _doubleClickCallback(doubleClickCallback), 
      _holdCallback(holdCallback),
      _doubleClickTime(doubleClickTime),
      _holdTime(holdTime),
      _debounceTime(debounceTime) 
{
    if (active == LOW)
        pinMode(_pin, INPUT_PULLUP);
    else
        pinMode(_pin, INPUT);
}

void PushBTN::loop() {
    switch (state)
    {
    case RELEASE:
        if (digitalRead(_pin) == _active) {
            holdTimer = millis();
            state = PUSH_WAIT;
        }
        break;
    
    case PUSH_WAIT:
        if ((millis() - holdTimer) > _debounceTime) {
          if (digitalRead(_pin) == _active) { // still hold after debounce
            state = HOLD_WAIT;
          } else {                           // mechanical/electrical noises
            state = RELEASE;
          }
        }
        break;

    case HOLD_WAIT:
        if (digitalRead(_pin) != _active) {   // just push (>5ms and <holdTime)
          state = PUSH;
        } else if ((millis() - holdTimer) > _holdTime) {
          state = HOLD;
        }
        break;

    case PUSH:
        clickCount++;
        if (clickCount == 1) {
            // Lần click đầu tiên - chờ xem có click lần 2 không
            doubleClickTimer = millis();
            state = DOUBLE_CLICK_WAIT;
        } else if (clickCount == 2) {
            // Click lần 2 - xác nhận double click
            state = DOUBLE_CLICK;
        }
        break;

    case DOUBLE_CLICK_WAIT:
        // Chờ trong khoảng thời gian doubleClickTime
        if (digitalRead(_pin) == _active) {
            // Phát hiện nhấn lần 2
            holdTimer = millis();
            state = PUSH_WAIT;
        } else if ((millis() - doubleClickTimer) > _doubleClickTime) {
            // Hết thời gian chờ - chỉ là single click
            _pushCallback();
            clickCount = 0;
            state = RELEASE;
        }
        break;

    case DOUBLE_CLICK:
        _doubleClickCallback();
        clickCount = 0;
        state = RELEASE_WAIT;
        break;

    case HOLD:
        _holdCallback();
        clickCount = 0;
        state = RELEASE_WAIT;
        break;

    case RELEASE_WAIT:
        if (digitalRead(_pin) != _active) {
          state = RELEASE;
        }
        break;
    }
}