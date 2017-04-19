#include <SoftwareSerial.h>

SoftwareSerial Xbee(6, 7); // RX, TX

void setup() {
  Serial.begin(19200);  //19200
  // put your setup code here, to run once:
  Xbee.begin(19200);
}

void loop() {
  for (int i = 0; i < 4; i++) { //reads 4 sensors
    //Serial.print(analogRead(i) / 4);
    int x = analogRead(i);
    Serial.print(x / 4);
    Xbee.print(x / 4);
    delay(5);
    if (i < 4) {
      Serial.print(" ");
      Xbee.print(" ");
      delay(5);
    }
  }
  Serial.print('\r');
  Xbee.print('\r');
  delay(5);
}

