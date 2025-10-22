#pragma once
#include <Arduino.h>

class LDR
{
public: 
    LDR(const byte pin);
    int readRaw();
    int readPercentage();
    bool isBright(int thresold);
private:
    const byte _pin;
};

/***Implement***/

LDR::LDR(const byte pin) : _pin(pin)
{
    pinMode(_pin, INPUT);
}

int LDR::readRaw() {
    return analogRead(_pin);
} 

int LDR::readPercentage() {
    int rawvalue = readRaw();
    return map(rawvalue, 0, 4095, 0, 100);
}

bool LDR::isBright(int thresold){
    return readRaw() > thresold;
}