#include <Arduino.h>
#include "LDR.h"

LDR ldr(LDR_PIN);

void setup() {
  Serial.begin(115200);
}


void loop() {
  int ldr_value = ldr.readRaw();
  Serial.println(ldr_value);

  Serial.print(">LDR value: ");
  Serial.println(ldr_value);
}