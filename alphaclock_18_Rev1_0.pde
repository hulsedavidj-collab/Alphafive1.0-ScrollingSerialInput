
/*
alphaclock_18.pde 
 
 
 Software for the Five Letter Word Clock desiged by
 Evil Mad Scientist Laboratories http://www.evilmadscientist.com
 
 Target: ATmega644A, clock at 16 MHz.
 
 Designed to work with Arduino 23; untested with other versions.
 Also (1) requires the "old" DateTime library:  http://www.arduino.cc/playground/Code/DateTime
 Also (2) requires Sanguino extensions to Arduino, rev 0023, available from: 
 http://code.google.com/p/sanguino/downloads/list
 
 * May require "boards.txt" file to be edited as well, for atmega644 (not -P).
 * May require "pins_arduino.c" and "pins_arduino.h" to be edited as well, for 644.
 - Arduino does not directly support the '644A, so the outgoing serial port may not be usable from 
 within the Arduino IDE.
 * Bootloader should be set to give device signature as ATmega644P.
 
 Untested with newer versions of Arduino.
 
 
 Version 1.0 - 12/17/2011
 Copyright (c) 2011 Windell H. Oskay.  All right reserved.
 http://www.evilmadscientist.com/
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this library.  If not, see <http://www.gnu.org/licenses/>.
 	  
 */


#include <EEPROM.h>            // For saving settings
#include <Wire.h>              // For optional RTC module
#include <DateTime.h>          // For optional Serial Sync
#include <DateTimeStrings.h>   // For optional Serial Sync


#define AllLEDsOff();  PORTA |= 127;  

// The buttons are located at PB0, PB1, PB2, PB3
#define buttonmask 15 

// Default "idle" time to wait before saving settings in EEPROM, usually 5 seconds (5000U)
#define IdleDelay  5000U


byte PINBLast;

byte SecNow; 

byte MinNow;
byte MinNowTens;
byte MinNowOnes;

byte HrNow;
byte HrNowTens;
byte HrNowOnes;


byte ZeroHourBlankNow;
byte IdleTimeEnded;


char AMPM24HdisplayNow;   // Units character

byte ZeroHourBlankAlrm;
char AMPM24HdisplayAlrm;
byte MinAlrmOnes;
byte MinAlrmTens;
byte HrAlrmOnes;
byte HrAlrmTens;

byte CharacterBuffer[10];  // What position in char array

byte bufl1[10];  // First byte  (low power)
byte bufh1[10];  // second byte (high power)
byte bufh2[10];  // third byte  (high power)

char stringTemp[5];

/* Start at ASCII 32 (decimal), character ' ' (space).
 Byte format: A, B, C, order sent to shift register.
 A: First byte,  "low power"
 B: Second byte, "high power," MSB
 C: Third byte,  "high power," LSB
 
 */

byte AlphaArray[] = {
  0,0,0,    // [space]  ASCII 32
  0,0,3,    // ! (Yes, lame, but it's the "standard." Better Suggestions welcome.)
  0,0,40,  // "
  63,3,255,    //#
  63,1,42,    //$
  57,3,106,    //%
  14,3,98,    //&
  0,0,64,      // '
  0,0,192,      // (
  0,2,16,      // )
  48,3,240,    // *
  48,1,32,      //+
  0,2,0,      //  ,
  48,0,0,      // -
  64,0,0,      // . (lower DP)
  0,2,64,    //  /
  15,0,15,  // 0
  0,0,3,     //1
  63,0,5,    //2
  47,0,3,    //3
  48,0,11,    //4
  63,0,10,    //5
  63,0,14,    //6
  3,0,3,      //7
  63,0,15,    //8
  63,0,11,    //9
  0,1,32,      //:
  0,2,32,      //;
  0,0,192,      //<
  60,0,0,      //=
  0,2,16,      //>
  34,1,1,      //?
  47,0,13,      //@
  51,0,15,      //A
  47,1,35,      //B
  15,0,12,      //C
  15,1,35,     //D
  31,0,12,      //E
  19,0,12,    //F
  47,0,14,      //G
  48,0,15,      //H
  15,1,32,        //I
  12,0,7,        //J
  16,0,204,      //K
  12,0,12,       //L
  0,0,95,        //M
  0,0,159,      //N
  15,0,15,      //O
  51,0,13,      //P
  15,0,143,    //Q
  51,0,141,    //R
  63,0,10,      //S
  3,1,32,      //T
  12,0,15,      //U
  0,2,76,      //V
  0,2,143,      //W
  0,2,208,      //X
  0,1,80,      //Y
  15,2,64,      //Z
  10,1,32,      // [
  0,0,144,      // backslash
  5,1,32,        // ]
  0,2,128,      // ^
  12,0,0,      // _
  0,0,16        // `
};

// Starting offset of our ASCII array:
#define asciiOffset 32  

// Starting offset for number zero
#define numberOffset 16


//Faster latch macro!
#define Latch();    PORTC |= 4;PORTC &= 251;    


void AlphaWrite (byte l1, byte h1, byte h2)
{  // Transmit data to to LED drivers through SPI
  PORTA |= 127; // Blank all character "rows" (A0-A5) and LED driver
  SPDR = l1;
  while (!(SPSR & _BV(SPIF))) {
  }  //Wait for transmission complete
  SPDR = h1;
  while (!(SPSR & _BV(SPIF))) {
  }  //Wait for transmission complete
  SPDR = h2;
  while (!(SPSR & _BV(SPIF))) {
  }  //Wait for transmission complete
}



byte OptionMode;    // Are we in the settings menu?   If so, what position?
// Number of option modes: (e.g., 2, if there are only two option modes)
#define OptionsMax 4
byte OptionNameSequence;  // State variable for multi-word option labels
byte SoundSequence;

unsigned long WordStopTime;
byte DisplayWordMode;
byte SerialDisplayMode;

byte LEDTestMode;
byte HoldLEDTest;
byte LEDTestStage;

void LoadCharBuffer (char WordIn[])
{ 

  CharacterBuffer[0] = (WordIn[4] - asciiOffset);
  CharacterBuffer[1] = (WordIn[3] - asciiOffset);
  CharacterBuffer[2] = (WordIn[2] - asciiOffset);
  CharacterBuffer[3] = (WordIn[1] - asciiOffset);
  CharacterBuffer[4] = (WordIn[0] - asciiOffset);
}

void DisplayWordSequence (char WordIn[], unsigned int durationMillis)
{
  WordStopTime = millis() + durationMillis; 

  CharacterBuffer[0] = (WordIn[4] - asciiOffset);
  CharacterBuffer[1] = (WordIn[3] - asciiOffset);
  CharacterBuffer[2] = (WordIn[2] - asciiOffset);
  CharacterBuffer[3] = (WordIn[1] - asciiOffset);
  CharacterBuffer[4] = (WordIn[0] - asciiOffset);

  LoadShiftRegBuffers();
  DisplayWordMode = 1; 
  OptionNameSequence++;
}



#define EELength 8
byte EEvalues[EELength];

byte MainBright;
byte FadeMode;  // Not used at present.
byte HourMode24;
byte AlarmEnabled; // If the "ALARM" function is currently turned on or off. 
byte AlarmTimeHr;
byte AlarmTimeMin;
byte NightLightType;   //0
byte AlarmTone;


// "Factory" default configuration can be configured here:
#define MainBrightDefault 5
#define FadeModeDefault 1 
#define HourMode24Default 0
#define AlarmEnabledDefault 0
#define AlarmTimeHrDefault 7
#define AlarmTimeMinDefault 30
#define NightLightTypeDefault 0
#define AlarmToneDefault 1

unsigned long LastTime;

//byte TimeSinceButton;
byte LastAlarmCheckMin;



byte ExtRTC;


void updateNightLight()
{

  if (NightLightType == 0)
    analogWrite(14, 0);   
  if (NightLightType == 1)
    analogWrite(14, 60);  
  if (NightLightType == 2)
    analogWrite(14, 255);  

}


#define TIME_MSG_LEN  13   // time sync to PC is HEADER followed by unix time_t as ten ascii digits  (Was 11)
#define TIME_HEADER  255   // Header tag for serial time sync message


boolean getPCtime() {
  char charTemp,  charTemp2;
  int i;

  // if time sync available from serial port, update time and return true
  while(Serial.available() >=  TIME_MSG_LEN ){  // time message consists of a header and ten ascii digits


    /*if (Serial.read() != TIME_HEADER)
     {
     while((Serial.peek() != TIME_HEADER) &&  (Serial.peek() >= 0))  // Flush buffer up until next 0xFF.    
     Serial.read();
     
     DisplayWordSequence("FLUSH",500);     //TODO: Remove this debug message
     }
     */

    if( Serial.read() == TIME_HEADER) { 

      //   DisplayWordSequence("RECV ",100);  //TODO: Remove this debug message
      //    Read command, next two bytes:
      charTemp = Serial.read();
      charTemp2 = Serial.read();

      if( charTemp == 'S' ){ 

        // DisplayWordSequence("RECVS",100);  //TODO: Remove this debug message
        if( charTemp2 == 'T' ){ 
          // Time setting mode:
          //DisplayWordSequence("RECVT",100);  //TODO: Remove this debug message

          time_t pctime = 0;
          for( i=0; i < 10; i++){   
            char c= Serial.read();          
            if( c >= '0' && c <= '9'){   
              pctime = (10 * pctime) + (c - '0') ; // convert digits to a number    
            }
          }   
          DateTime.sync(pctime);   // Sync Arduino clock to the time received on the serial port
          return true;   // return true if time message received on the serial port
        }

      }

      else if( charTemp == 'A' ){  
        if( charTemp2 == '0' )  {

          //  DisplayWordSequence("RECA0",500);  //TODO: Remove this debug message
          // ASCII display mode, first 5 chars will be displayed.

          for( i=0; i < 10; i++){   
            charTemp = Serial.read();          

            if (i < 5)
            {
              CharacterBuffer[4 - i] = charTemp - asciiOffset;
            } 
            else
            {
              CharacterBuffer[i] = charTemp;
            }

          }   

          LoadShiftRegBuffers(); 
          DisplayWordMode = 1;  


          for( i=5; i < 10; i++){  

            if (CharacterBuffer[i] == 'L')
              bufl1[9 - i] |= 64;  // Add lower DP 
            if (CharacterBuffer[i] == 'U')
              bufl1[9 - i] |= 128;  // Add upper DP 
            if (CharacterBuffer[i] == 'B')
              bufl1[9 - i] |= 192;  // Add both DPs 

          }
          SerialDisplayMode  = 1;
          // Serial.println("Writing Text!");
        }
      }
      else if( charTemp == 'M' ){ 
        if( charTemp2 == 'T' )
        {
          // Clock display mode
          SerialDisplayMode  = 0;
          // Serial.println("Resuming clock display!");
          for( i=0; i < 10; i++){     // Read dummy input....
            charTemp = Serial.read();          
          } 
        }

      }
    }
    else
    {
      DisplayWordSequence("ERROR",200);  //Display error!
    }
  }
  return false;  //if no message return false

}


void printDigits(byte digits){
  // utility function for digital clock display: prints preceding colon and leading 0
  Serial.print(":");
  if(digits < 10)
    Serial.print('0');
  Serial.print(digits,DEC);
}

void digitalClockDisplay(){
  // digital clock display of current date and time
  Serial.print(DateTime.Hour,DEC);
  printDigits(DateTime.Minute);
  printDigits(DateTime.Second);
  Serial.print(" ");
  Serial.print(DateTimeStrings.dayStr(DateTime.DayofWeek));
  Serial.print(" ");
  Serial.print(DateTimeStrings.monthStr(DateTime.Month));
  Serial.print(" ");
  Serial.println(DateTime.Day,DEC); 
}


// Modes: 

byte VCRmode;  // In VCR mode, the clock blinks at you because the time hasn't been set yet.
//byte FactoryResetDisable;  // To make sure that we don't accidentally reset the settings...

byte SettingTime;
byte SettingAlarm; 
byte AlarmNow;    // Alarm is actually going off, right now.

byte HoldTimeSet;
byte HoldOption;
byte HoldAlarmSet;
byte HoldLoopCount;

byte     MomentaryOverridePlus; 
byte     MomentaryOverrideMinus; 

unsigned long prevtime;
unsigned long millisCopy; 
unsigned long NextAdvance;
unsigned long NextAdvanceSound;
unsigned long endIdleTime;

void ApplyDefaults (void) {

  // VARIABLES THAT HAVE EEPROM STORAGE AND DEFAULTS...
  // FadeMode = FadeModeDefault; 

  MainBright = MainBrightDefault;
  HourMode24 = HourMode24Default;
  AlarmEnabled = AlarmEnabledDefault;
  AlarmTimeHr = AlarmTimeHrDefault;
  AlarmTimeMin = AlarmTimeMinDefault;
  AlarmTone = AlarmToneDefault;
  NightLightType = NightLightTypeDefault;  
}

void EEReadSettings (void) { 

  byte detectBad = 0; 
  byte value = 255;

  value = EEPROM.read(0);      

  if ((value >= 1) && (value <= 13))
    MainBright = value;  // MainBright has maximum possible value of 13.    
  else  {
    MainBright = MainBrightDefault;  // Turn back on when power goes back on-- don't leave it dark.
    EESaveSettings();
}

  value = EEPROM.read(1);
  if (value > 1)
    detectBad = 1;
  else  
    HourMode24 = value;


  value = EEPROM.read(2);
  if (value > 1)
    detectBad = 1;
  else  
    AlarmEnabled = value;

  value = EEPROM.read(3);
  if (value > 23)
    detectBad = 1;
  else  
    AlarmTimeHr = value;   

  value = EEPROM.read(4);
  if (value > 59)
    detectBad = 1;
  else  
    AlarmTimeMin = value;   

  value = EEPROM.read(5);
  if (value > 4)
    detectBad = 1;
  else  
    AlarmTone = value;      

  value = EEPROM.read(6);
  if (value > 4)
    detectBad = 1;
  else  
    NightLightType = value;      
/*
if (detectBad){
    ApplyDefaults();
    EESaveSettings();
}
*/

}

void EESaveSettings (void){
  //EEPROM.write(Addr, Value);

  byte detectBad = 0; 
  byte EEPROMwritten = 0; 
  byte value = 255;

  // Careful if you use  this function: EEPROM has a limited number of write
  // cycles in its life.  Good for human-operated buttons, bad for automation.

  if (MainBright > 13)
    detectBad = 1;
  else  
  {
    value = EEPROM.read(0);  
    if (MainBright != value){
      EEPROM.write(0, MainBright);
      EEPROMwritten = 1;
    }
  }

  if (HourMode24 > 1)
    detectBad = 1;
  else  
  {
    value = EEPROM.read(1);  
    if (HourMode24 != value){
      EEPROM.write(1, HourMode24); 
      EEPROMwritten = 1;
    }
  }

  if (AlarmEnabled > 1)
    detectBad = 1;
  else  
  {
    value = EEPROM.read(2);  
    if (AlarmEnabled != value){
      EEPROM.write(2, AlarmEnabled); 
      EEPROMwritten = 1;
    }
  }

  if (AlarmTimeHr > 23)
    detectBad = 1;
  else  
  {
    value = EEPROM.read(3);  
    if (AlarmTimeHr != value){
      EEPROM.write(3, AlarmTimeHr);
      EEPROMwritten = 1;
    }
  }

  if (AlarmTimeMin > 59)
    detectBad = 1;
  else  
  {
    value = EEPROM.read(4);  
    if (AlarmTimeMin != value){
      EEPROM.write(4, AlarmTimeMin);
      EEPROMwritten = 1;
    }
  }


  if (AlarmTone > 4)
    detectBad = 1;
  else  
  {
    value = EEPROM.read(5);  
    if (AlarmTone != value){
      EEPROM.write(5, AlarmTone);
      EEPROMwritten = 1;
    }
  }


  if (NightLightType > 4)
    detectBad = 1;
  else  
  {
    value = EEPROM.read(6);  
    if (NightLightType != value){
      EEPROM.write(6, NightLightType); 
      EEPROMwritten = 1;
    }
  }



  // Optional: Blink LEDs off to indicate when we're writing to the EEPROM


  if (EEPROMwritten)
  {   
    AllLEDsOff();
    delay(100);
  }


}




void RTCsetTime(byte hourIn, byte minuteIn, byte secondIn)
{
  Wire.beginTransmission(104); // 104 is DS3231 device address
  Wire.send(0); // start at register 0

    byte ts = secondIn / 10;
  byte os = secondIn - ts*10;
  byte ss = (ts << 4) + os;

  Wire.send(ss); //Send seconds as BCD

  byte tm = minuteIn /10;
  byte om = minuteIn - tm*10;
  byte sm = (tm << 4 ) | om;

  Wire.send(sm); //Send minutes as BCD

  byte th = hourIn /10;
  byte oh = hourIn - th*10;
  byte sh = (th << 4 ) | oh;

  Wire.send(sh); //Send hours as BCD

  Wire.endTransmission();  

}

byte RTCgetTime()
{ // Read out time from RTC module, if present
  // send request to receive data starting at register 0

  byte status = 0; 
  Wire.beginTransmission(104); // 104 is DS3231 device address
  Wire.send(0); // start at register 0
  Wire.endTransmission();
  Wire.requestFrom(104, 3); // request three bytes (seconds, minutes, hours)

  int seconds, minutes, hours;
  unsigned int temptime1, temptime2;
  byte updatetime = 0;

  while(Wire.available())
  { 
    status = 1;
    seconds = Wire.receive(); // get seconds
    minutes = Wire.receive(); // get minutes
    hours = Wire.receive();   // get hours
  }

  // IF time is off by MORE than two seconds, then correct the displayed time.
  // Otherwise, DO NOT update the time, it may be a sampling error rather than an
  // actual offset.
  // Skip checking if minutes == 0. -- the 12:00:00 rollover is distracting,
  // UNLESS this is the first time running after reset.

  // if (ExtRTC) is equivalent to saying,  "if this has run before"

  if (status){
    seconds = (((seconds & 0b11110000)>>4)*10 + (seconds & 0b00001111)); // convert BCD to decimal
    minutes = (((minutes & 0b11110000)>>4)*10 + (minutes & 0b00001111)); // convert BCD to decimal
    hours = (((hours & 0b00110000)>>4)*10 + (hours & 0b00001111)); // convert BCD to decimal (assume 24 hour mode)

    //Optional: report time:: 
    // Serial.print(hours); Serial.print(":"); Serial.print(minutes); Serial.print(":"); Serial.println(seconds);


    if ((minutes) && (MinNow) ){
      temptime1 = 3600*hours + 60*minutes + seconds;  // Values read from RTC
      temptime2 = 3600*HrNow + 60*MinNow + SecNow;    // Internally stored time estimate.

      if (temptime1 > temptime2)
      { 
        if ((temptime1 - temptime2) > 2)
          updatetime = 1;
      }
      else
      { 
        if ((temptime2 - temptime1) > 2)
          updatetime = 1;
      } 
    }

    if (ExtRTC == 0)
      updatetime = 1;

    if (updatetime)
    {
      SecNow = seconds;
      MinNow = minutes;
      HrNow = hours;

    }
  }

  return status;
}




byte AlarmTimeSnoozeMin;
byte AlarmTimeSnoozeHr;
byte snoozed;




void CalculateNewTime (void)
{  // Update current display representation of the time

  if (SecNow > 59){
    SecNow -= 60;
    MinNow++;


    if (IdleTimeEnded)   { // Skip this step if there has been a recent button press.
      if ((SettingTime == 0) && ExtRTC) // Check value at RTC ONCE PER MINUTE, if enabled.
        RTCgetTime();              // Do not check RTC time, if we are in time-setting mode.
    }
  }

  if (MinNow > 59){
    MinNow -= 60;
    HrNow++; 

    if  (HrNow > 23)
      HrNow -= 24; 
  }


  MinNowTens = MinNow / 10;
  MinNowOnes = MinNow - 10 * MinNowTens;

  ZeroHourBlankNow = 0;

  if (HourMode24 ){
    HrNowTens = HrNow / 10;
    HrNowOnes = HrNow - 10 * HrNowTens;

    AMPM24HdisplayNow = 'H';

  }
  else
  {
    byte HrNowTemp = HrNow;
    if (HrNow >= 12)
    {
      HrNowTemp -= 12;
      AMPM24HdisplayNow = 'P';
    }
    else
      AMPM24HdisplayNow = 'A';

    if (HrNowTemp == 0 )
    {
      HrNowTens = 1;
      HrNowOnes = 2;
    } 
    else{   
      HrNowTens = HrNowTemp / 10;
      HrNowOnes = HrNowTemp - 10 * HrNowTens;

      if (HrNowTens == 0)
        ZeroHourBlankNow = 1;
    }
  }



  if (LastAlarmCheckMin != MinNow)
  {  // Only check once per minute
    if (AlarmEnabled)  {

      if ((AlarmTimeHr == HrNow ) && (AlarmTimeMin == MinNow ))
      {
        AlarmNow = 1;
        snoozed = 0;
        NextAdvanceSound = 0;
        SoundSequence = 0;
      }

      if (snoozed)
        if  ((AlarmTimeSnoozeHr == HrNow ) && (AlarmTimeSnoozeMin == MinNow ))
        {
          AlarmNow = 1;
          snoozed = 0;
          NextAdvanceSound = 0;
          SoundSequence = 0;
        }
    }

    LastAlarmCheckMin = MinNow;

  }

}

void CalculateNewAlarm (void)
{  // Update current display representation of the Alarm time

  if (AlarmTimeMin > 59){
    AlarmTimeMin -= 60;
    AlarmTimeHr++; 

    if  (AlarmTimeHr > 23)
      AlarmTimeHr = 0; 
  }

  MinAlrmTens = AlarmTimeMin / 10;
  MinAlrmOnes = AlarmTimeMin - 10 * MinAlrmTens;

  ZeroHourBlankAlrm = 0;

  if (HourMode24 ){
    HrAlrmTens = AlarmTimeHr / 10;
    HrAlrmOnes = AlarmTimeHr - 10 * HrAlrmTens;

    AMPM24HdisplayAlrm = 'H';
  }
  else
  {
    byte AlarmTimeHrTemp = AlarmTimeHr;
    if (AlarmTimeHr >= 12)
    {
      AlarmTimeHrTemp -= 12;
      AMPM24HdisplayAlrm = 'P';
    }
    else
      AMPM24HdisplayAlrm = 'A';

    if (AlarmTimeHrTemp == 0 )
    {
      HrAlrmTens = 1;
      HrAlrmOnes = 2;
    } 
    else{   
      HrAlrmTens = AlarmTimeHrTemp / 10;
      HrAlrmOnes = AlarmTimeHrTemp - 10 * HrAlrmTens;

      if (HrAlrmTens == 0)
        ZeroHourBlankAlrm = 1;
    }
  }

  snoozed = 0;  //  Recalculating alarm time *turns snoose off.*

  if (AlarmEnabled)  
    if ((AlarmTimeHr == HrNow ) && (AlarmTimeMin == MinNow ))
    {
      AlarmNow = 1;
      NextAdvanceSound = 0;
      SoundSequence = 0;
    } 

}




void LoadShiftRegBuffers( void)
{
  // Map the 5-character cotents of the ASCII Character Buffer into the 15 SPI output bytes
  //  (three bytes per LED character) needed to draw those characters.
  byte alphaPosTemp;
  byte j = 0;
  while (j < 5)
  {
    alphaPosTemp = 3 * CharacterBuffer[j];
    bufl1[j] = AlphaArray[alphaPosTemp++];
    bufh1[j] = AlphaArray[alphaPosTemp++];
    bufh2[j] = AlphaArray[alphaPosTemp];     
    j++;
  }
}



void refreshDisplay (void)
{

  byte k1, k2; // temporary register values
  byte i,j; // dummy variables
  unsigned int onPeriod;
  unsigned int offPeriod;

  //MainBright can be 0 to 13; 14 levels of brightness. 0 is OFF.
  //MainBright = 1;  // for test only


  byte tempbright = MainBright;

  if (VCRmode){
    if (SecNow & 1) 
      tempbright = 0; 
  }



  if (tempbright == 0)
  {
    PORTA |= 64;    // Blank LED driver 

  }
  else if (tempbright < 5)
  {

    offPeriod = 240;
    if (tempbright == 2)
      offPeriod = 60;
    if (tempbright == 3)
      offPeriod = 15;
    if (tempbright == 4)
      offPeriod = 3;

    i = 0;
    while (i < 32)  // Number of loops through the five digits (for low-power modes) // Normally 32
    {
      j = 0;
      while (j < 5)
      {

        AlphaWrite(bufl1[j],bufh1[j],bufh2[j]);      
        Latch();
        PORTA &= ~(1 << j);  // Enable character
        //PORTA &= 191;  // Enable LED Driver

        k1 = PORTA & 191;   // Enable LED Driver
        k2 = PORTA | 64;    // Blank LED driver    //  Was  PORTA |= _BV(6);


        // For low brightness levels, we use a very low duty cycle PWM.
        // That's normally fine, but the Arduino interrupts in the background
        // (for example, the one that keeps our millisecond timer accurate!)
        // create tiny timing varations, and so these short "on" bursts
        // can have *very* poor consistency, leading to a jittery, flickery
        // display.  To get around this, we temporarily turn off interrupts,
        // for just long enough to turn on the LEDs for a few clock cycles
        // (under 1 us).   Once interrupts are back on, pending interrupt
        // requests will be serviced, so we should not lose any time in the
        // process.  *However* take great care if you extend this 
        // "interrupt free" section of the code to any longer duration.


        byte SREGtemp = SREG;
        cli(); // Disable interrupts
        PORTA = k1;

        asm volatile("nop\n\t"
          "nop\n\t"
          "nop\n\t"
          "nop\n\t"
          "nop\n\t"
          ::);

        PORTA = k2;
        SREG = SREGtemp; // reenable interrupts.

        delayMicroseconds(offPeriod);

        j++;
      }
      i++;
    }
  }
  else
  {    // Higher duty-cycle modes
    if (tempbright > 12)
    {
      tempbright = 13; 
    }
    //   onPeriod =  15 + ((tempbright - 3) * (tempbright - 3) ) * 4;  // Nonlinear brightness scale!
    //   offPeriod = 339 - onPeriod;

    onPeriod =  15 + ((tempbright - 4) * (tempbright - 4) ) * 2;  // Nonlinear brightness scale!
    offPeriod = 178 - onPeriod;




    i = 0;
    while (i < 16)  // Number of loops through the five digits (for high-power modes) // Normally 16
    {

      j = 0;
      while (j < 5)

      {

        AlphaWrite(bufl1[j],bufh1[j],bufh2[j]);      
        Latch();
        PORTA &= ~(1 << j);  // Enable character
        //PORTA &= 191;  // Enable LED Driver

        k1 = PORTA & 191;   // Enable LED Driver
        k2 = PORTA | 64;    // Blank LED driver    //  Was  PORTA |= _BV(6);

        PORTA = k1;
        delayMicroseconds(onPeriod);  
        PORTA = k2;

        if (offPeriod != 0)
          delayMicroseconds(offPeriod);

        j++;
      }
      i++;
    }
  }

}


void TurnAlarmOff (void)
{       
  AlarmNow = 0;
  noTone(13);
  PORTD |= 32; // Turn off speaker

}

void setup()                    // run once, when the sketch starts
{ 

  PORTA = 127;
  PORTB = buttonmask;  // Pull-up resistors for buttons
  PORTC = 3;  // PULL UPS for I2C
  PORTD = 0;

  DDRD = _BV(6) | _BV(7);  // LED on PD6, PD7
  DDRC = _BV(2);  // Latch pin, PC2    
  DDRB = _BV(4) | _BV(5) | _BV(7);  // SS, SCK, MOSI are outputs 
  DDRA = 127;  // Outputs: PA0-PA5 ("rows") and Blank pin, PA6

  //ENABLE SPI, MASTER, CLOCK RATE fck/4:	
  SPCR = _BV(SPE) | _BV(MSTR);  // Initialize SPI, fast!
  SPSR |= 1;  // enable double-speed mode!	

  AlphaWrite(0,0,0); 
  Latch();

  SecNow = 0; 
  MinNow = 0;
  MinNowTens = 0;
  MinNowOnes = 0;

  HrNow = 0;
  HrNowTens = 0;
  HrNowOnes = 0;

  LEDTestMode = 0;
  HoldLEDTest = 0;
  SerialDisplayMode = 0;

  ZeroHourBlankNow = 0;
  IdleTimeEnded = 1;
  ZeroHourBlankAlrm = 0;
  AMPM24HdisplayAlrm = ' ';
  MinAlrmOnes = 0;
  MinAlrmTens = 0;
  HrAlrmOnes = 0;
  HrAlrmTens = 0;
  VCRmode = 0;  // Time is NOT yet set, but this should be zero until after "hello world."
  OptionMode = 0;

  LastAlarmCheckMin = 0;
  HoldLoopCount = 0; 

  EEReadSettings();   // Read stored settings from EEPROM.

  updateNightLight();


  VCRmode = 1;  // Time is NOT yet set.
  //FactoryResetDisable = 0;    

  PINBLast =  PINB & buttonmask;

  HoldTimeSet = 0;
  HoldAlarmSet = 0;
  HoldOption = 0;

  MomentaryOverridePlus = 0; 
  MomentaryOverrideMinus = 0;


  SettingTime = 0;  // Normally 0, while not setting time.   

  SettingAlarm = 0;  // Same deal.

  PORTA |= _BV(6); // Blank LED driver

  DisplayWordSequence("HELLO",1000); 

  while (  millis() < WordStopTime){    
    refreshDisplay ();
    DisplayWordMode = 0;
  }

  delay (10);

  DisplayWordSequence("WORLD",2000);

  while (  millis() < WordStopTime){    
    refreshDisplay ();
    DisplayWordMode = 0;
  }

  delay (250);


  VCRmode = 1;  // Time is NOT yet set.

  Serial.begin(19200);
  DateTime.sync(0); 

  Wire.begin();


  ExtRTC = 0;
  // Check if RTC is avaiiable, and use it to set the time if so.
  ExtRTC = RTCgetTime();
  // If no RTC is found, no attempt will be made to use it thereafter.

  if (ExtRTC)          // If time is already set from the RTC...
    VCRmode = 0;

  CalculateNewTime();
  CalculateNewAlarm();

  TurnAlarmOff(); 
  snoozed = 0;
  noTone(13);	
  PORTD |= 32; // Turn off speaker
}  // End Setup



void loop()
{ 
  //byte HighLine, LowLine;
  byte PINBcopy;
  //byte alphaPosTemp;
  byte i,j;  // Dummy indices


  millisCopy = millis(); 

  PINBcopy = PINB & buttonmask;

  if (PINBcopy != PINBLast)  // Button change detected
  { 

    endIdleTime = millisCopy + IdleDelay; //  Idle time for EEPROM purposes is 5 seconds.
    IdleTimeEnded = 0;

    VCRmode = 0;  // End once any buttons have been pressed...
    //TimeSinceButton = 0;

    if ((PINBcopy & 1) && ((PINBLast & 1) == 0)) 
    { //"Snooze" / Set Alarm Time Button was pressed and just released!



      if (OptionMode) {

        if ( OptionMode > 1)
          OptionMode--;
        else
          OptionMode = OptionsMax;
        OptionNameSequence = 0;
        TurnAlarmOff(); 
      }
      else if (SettingAlarm) {
        SettingAlarm = 0;  // End alarm time display/setting mode, when the "Snooze" button is released.
      }  
      else if (AlarmNow)
      {         
        snoozed = 1;
        TurnAlarmOff(); 	
        DisplayWordSequence("SNOOZ",2500); 

        AlarmTimeSnoozeHr = HrNow;
        AlarmTimeSnoozeMin  = MinNow + 9;    // Nine minutes, from time *snooze button pressed*

        if  ( AlarmTimeSnoozeMin > 59){
          AlarmTimeSnoozeMin -= 60;
          AlarmTimeSnoozeHr += 1;
        }
        if (AlarmTimeSnoozeHr > 23)
          AlarmTimeSnoozeHr -= 24;
      } 


    }

    if ((PINBcopy & 2) && ((PINBLast & 2) == 0)) 
    { //"Time" / Alarm On/off Button was pressed and just released!


      if (OptionMode) {

        if ( OptionMode < OptionsMax)
          OptionMode++;
        else
          OptionMode = 1;

        OptionNameSequence = 0;
        TurnAlarmOff(); 
      }
      else if ((AlarmNow) || (snoozed)){  // Just Turn Off Alarm

        TurnAlarmOff();  
        snoozed = 0;

        delay (100);
        DisplayWordSequence("ALARM",1000);

        while (  millis() < WordStopTime){    
          refreshDisplay ();
          DisplayWordMode = 0;
        }

        delay (100);

        DisplayWordSequence(" OFF ",1000);

        while (  millis() < WordStopTime){    
          refreshDisplay ();
          DisplayWordMode = 0;
        }

        delay (100);

      }
      else if (SettingTime) {
        // We *have* been setting the time, but have just released the button.


        SettingTime = 0; // Turn off time-setting mode.


        if  (ExtRTC) // Write the new time to the RTC, RIGHT NOW.
        {
          RTCsetTime(HrNow,MinNow,SecNow);             
        }


      } 
      else { 
        // Normal adjustment mode.
        if (AlarmEnabled)
          AlarmEnabled = 0;
        else  
          AlarmEnabled = 1;    


      }  
    }

    if ((PINBcopy & 4) && ((PINBLast & 4) == 0))  //"+" Button was just released!
    { 
      if ( MomentaryOverridePlus)
      {  
        MomentaryOverridePlus = 0; 
        // Ignore this transition if it was part of a hold sequence.
      }
      else
      {
        if (OptionMode) {

          if (OptionMode == 1)  {
            // 24-HR - AM/PM mode switch

            if (HourMode24)
              HourMode24 = 0;
            else
              HourMode24 = 1;

            CalculateNewTime();    // Make sure time is ready to display, in the correct format!
            CalculateNewAlarm();   // Make sure alarm is ready to display!, in the correct format!

          }
          else if (OptionMode == 2) {
            if (NightLightType < 2)
              NightLightType++;
            else 
              NightLightType = 0;

            updateNightLight();
          }
          else if (OptionMode == 3) {
            if (AlarmTone < 3)
              AlarmTone++;
            else 
              AlarmTone = 0;

          }
          else if (OptionMode == 4) {
            // ACTIVATE Alarm test mode!   Momentarily turn the alarm on.
            SoundSequence = 0; 
            AlarmNow = 1;
          }

        }
        else if ((PINBcopy & 2) == 0)   {  // Time-setting button is currently depressed

          SettingTime = 1;  // Flag that we are now changing the time.
          MinNow++;       // Advance the time!
          CalculateNewTime();

        }
        else if ((PINBcopy & 1) == 0)   {  // Alarm-setting button is currently depressed

          SettingAlarm = 1;  // Individual step mode 
          AlarmTimeMin++;       // Advance the Alarm time!   

          CalculateNewAlarm();

        } 
        else {  
          // Brightness control mode
          if (MainBright < 13)
            MainBright++; 
        } 
      }
    }


    if ((PINBcopy & 8) && ((PINBLast & 8) == 0))
    { //"-" Button was pressed and just released!

      if ( MomentaryOverrideMinus)
      {  
        MomentaryOverrideMinus = 0; 
        // Ignore this transition if it was part of a hold sequence.
      }
      else
      {

        if (OptionMode) {

          if (OptionMode == 1)  {
            // 24-HR - AM/PM mode switch

            if (HourMode24)
              HourMode24 = 0;
            else
              HourMode24 = 1;

            CalculateNewTime();    // Make sure time is ready to display, in the correct format!
            CalculateNewAlarm();   // Make sure alarm is ready to display!, in the correct format!

          }
          else if (OptionMode == 2) {
            if (NightLightType > 0)
              NightLightType--;
            else 
              NightLightType = 2;
            updateNightLight();
          }
          else if (OptionMode == 3) {
            if (AlarmTone > 0)
              AlarmTone--;
            else 
              AlarmTone = 3;
          }
          else if (OptionMode == 4) {
            // Alarm test mode!
            TurnAlarmOff(); 
          }
        }
        else if ((PINBcopy & 2) == 0)   {  // Time-setting button is currently depressed

          SettingTime = 1;  // Declare that we are in individual step mode 

          if (MinNow > 0) 
            MinNow--;       // Decrement the time!
          else 
          {
            MinNow = 59;
            if (HrNow > 0)
              HrNow--;
            else{
              HrNow = 23;
            }
          }

          CalculateNewTime();

        }
        else if ((PINBcopy & 1) == 0)   {  // Alarm-setting button is currently depressed

          SettingAlarm = 2;  // Individual step mode  

          if (AlarmTimeMin > 0) 
            AlarmTimeMin--;       // Decrement the alarm time!
          else 
          {
            AlarmTimeMin = 59;
            if (AlarmTimeHr > 0)
              AlarmTimeHr--;
            else{
              AlarmTimeHr = 23;
            }
          }

          CalculateNewAlarm();

        } 
        else {  //Normal brightness adjustment mode
          if (MainBright > 0)
            MainBright--; 
        }   
      } 
    }
  }


  PINBLast = PINBcopy; 

  // The next if statement detects and deals with the millis() rollover.
  // This introduces an error of up to  1 s, about every 50 days.  
  //
  // (If you have the standard quartz timebase, this will not dominate the inaccuracy.
  // If you have the optional RTC, this error will be corrected next time we read the
  // time from the RTC.)

  if (millisCopy < LastTime) { 
    LastTime = 0;
    NextAdvance = 0;      // Other variables that could cause issues if millis rolls over!
    WordStopTime = 0;    // Other variables that could cause issues if millis rolls over!
  }

  if ((millisCopy - LastTime) >= 1000)
  {
    LastTime += 1000;    


    // Check to see if any buttons are being held down:

    if (( PINB & buttonmask) == buttonmask)
    {  // No buttons are pressed.
      // Reset the variables that check to see if buttons are being held down.

      HoldTimeSet = 0;
      HoldOption = 0;
      HoldAlarmSet = 0;
      HoldLEDTest = 0;

      // FactoryResetDisable = 1;

      // Save EEPROM if updated.
      if (millisCopy  > endIdleTime)
      {
        if (IdleTimeEnded == 0){
          EESaveSettings(); 
          IdleTimeEnded = 1;
        }
      }


    }
    else
    {   // At least one button is down!

      // Note which buttons are being held down

      if ((( PINB & buttonmask) == 10) ||(( PINB & buttonmask) == 6))   // Alarm-time set is down 
      { // Alarm button is down, and so is EITHER + or -. 

        HoldAlarmSet++;   
        HoldOption = 0;
        HoldTimeSet = 0;
        HoldLEDTest = 0;
      }

      if ((( PINB & buttonmask) == 9) ||(( PINB & buttonmask) == 5)) //Time-set is pressed down. 
      { // Time button is down, and so is EITHER + or -. 

        HoldTimeSet++;       
        HoldOption = 0;
        HoldAlarmSet = 0;
        HoldLEDTest = 0;
      }

      if (( PINB & buttonmask) == 3)  // "+" and "-" are down.
      {
        HoldOption++;   // We are holding for option setting mode.
        HoldTimeSet = 0;
        HoldAlarmSet = 0;
        HoldLEDTest = 0;
      }     

      if (( PINB & buttonmask) == 12)  // "time" and "alarm" are down.
      {
        if (HoldLEDTest < 5)
          HoldLEDTest++;   // We are holding for option setting mode.
        HoldTimeSet = 0;
        HoldAlarmSet = 0;
        HoldOption = 0;


      }     

    } 

    if (HoldAlarmSet > 1)
    { 
      MomentaryOverridePlus = 1;       // Override momentary-action of switches
      MomentaryOverrideMinus = 1;      // since we've detected a hold-down condition.
      //MomentaryOverrideSetAlarm = 1;

      OptionMode = 0;



      if (HoldAlarmSet > 5)
        HoldAlarmSet = 5;


      /*  // TODO: Add factory restore option
       // Hold + and - for 3 s AT POWER ON to restore factory settings.
       if ( FactoryResetDisable == 0){ 
       ApplyDefaults();
       EESaveSettings();
       AllLEDsOff();        // Blink LEDs off to indicate restoring data
       delay(100);
       }
       else
       {
       if (AlignMode) {
       AlignMode = 0; 
       } 
       else {
       }
       }
       */
    }

    if (HoldLEDTest == 4)  //"time" and "alarm" Held down, together, for 4 seconds
    {   
      if (LEDTestMode)
        LEDTestMode = 0;
      else{
        LEDTestMode = 1;
        DisplayWordSequence("VER10",2000);   // Display software version number, 1.0
        bufl1[1] |= 64;  // Add lower DP for proper "1.0" !
      }
    }


    if (HoldOption == 2)  // + and - Held down, together, for 2 seconds
    {   

      MomentaryOverridePlus = 1;
      MomentaryOverrideMinus = 1;      // since we've detected a hold-down condition.

      if (OptionMode) {
        OptionMode = 0;  
      } 
      else {
        OptionMode = 1;  // On *and* set position in menu.
      }
    }

    if (HoldTimeSet > 1)
    { 
      MomentaryOverridePlus = 1;       // Override momentary-action of switches
      MomentaryOverrideMinus = 1;      // since we've detected a hold-down condition.
      // MomentaryOverrideSetTime = 1;

      OptionMode = 0;
      SettingAlarm = 0;

      if (HoldTimeSet > 5)
        HoldTimeSet = 5;
    }

    // Note: this section could act funny if you hold the buttons for 256 or more seconds.  
    // So... um... don't do that.  :P

    SecNow++;       // Advance the time!
    CalculateNewTime();
  }   


  if (( PINB & buttonmask) == buttonmask) {
    HoldTimeSet = 0;
    HoldOption = 0;
    HoldAlarmSet = 0;
    //FactoryResetDisable = 1;
  }
  else {   // Other "Immediate" actions if buttons are being held

    // Detect if + or - is released while scanning time (real or alarm) forwards or backwards.

    if (( PINB & 12) == 12){
      HoldAlarmSet = 0;
      HoldTimeSet = 0;
    }

    if (millisCopy > NextAdvance)     //Holding buttons to advance time settings...
    {
      if (( PINB & buttonmask) == 10)    // Alarm +
      {
        if (HoldAlarmSet > 1)
        {      
          AlarmTimeMin++;       // Advance the Alarm time!   
          CalculateNewAlarm();
        }
        NextAdvance = millisCopy + (501 - 100 * (unsigned long) HoldAlarmSet);
      }
      if (( PINB & buttonmask) == 6)   // Alarm -
      {
        if (HoldAlarmSet > 1)
        { 
          if (AlarmTimeMin > 0) 
            AlarmTimeMin--;       // Decrement the alarm time!
          else 
          {
            AlarmTimeMin = 59;
            if (AlarmTimeHr > 0)
              AlarmTimeHr--;
            else{
              AlarmTimeHr = 23;
            }
          }

          CalculateNewAlarm();
        }
        NextAdvance = millisCopy + (501 - 100 * (unsigned long) HoldAlarmSet);          

      }      
      if (( PINB & buttonmask) == 9)   // Time + 
      {

        if (HoldTimeSet > 1)
        { 
          MinNow++;       // Advance the time!
          SettingTime = 1;  // Flag that time is changing, so that we don't reset it by RTC.idl
          CalculateNewTime();
        } 
        NextAdvance = millisCopy + (501 - 100 * (unsigned long)  HoldTimeSet);    
      }
      if (( PINB & buttonmask) == 5) // Time -
      { 
        if (HoldTimeSet > 1)
        { 
          SettingTime = 1;  // Flag that time is changing, so that we don't reset it by RTC.
          if (MinNow > 0) 
            MinNow--;       // Decrement the time!
          else 
          {
            MinNow = 59;
            if (HrNow > 0)
              HrNow--;
            else{
              HrNow = 23;
            }
          }
          CalculateNewTime();
        }
        NextAdvance = millisCopy + (501 - 100 * (unsigned long) HoldTimeSet);       
      }
    }
  }



  if (AlarmNow )        // Visual display and sounds durign ALARM sequences
  { 
    if (OptionMode == 0)
    {    // If we are testing the alarm sound in option mode, 
      // do not change the display.
      if (SecNow & 1) {

        DisplayWordSequence("ALARM",100);
        //LoadShiftRegBuffers();
        //DisplayWordMode = 1; 
      }
    }

    //SoundSequence
    if (millisCopy > NextAdvanceSound){

      if (AlarmTone == 3)   // Siren Tone
      {
        if (SoundSequence < 200)
        {
          tone(13, 20 + 5 * SoundSequence, 20);
          NextAdvanceSound = millisCopy + 10;
          SoundSequence++;
        }
        else if (SoundSequence == 200)
        { 
          tone(13, 20 + 5 * SoundSequence, 2000);
          NextAdvanceSound = millisCopy + 1500;
          SoundSequence++;
        } 
        else {
        NextAdvanceSound = millisCopy + 1000;
         SoundSequence = 0;
         noTone(13);
           PORTD |= 32; // Turn off speaker
        }

      }
      else   if (AlarmTone == 2)   // Low Tone
      {
        if (SoundSequence < 8)
        {
          if (SoundSequence & 1)
          {
            tone(13, 100, 300);
            NextAdvanceSound = millisCopy + 200;
            SoundSequence++;
          }
          else
          {
            NextAdvanceSound = millisCopy + 200;
            SoundSequence++;  
            noTone(13);  
            PORTD |= 32; // Turn off speaker   
            //
          }
        }
        else
        { 
          NextAdvanceSound = millisCopy + 1000;
          SoundSequence = 0;
          noTone(13);  
          PORTD |= 32; // Turn off speaker  
        }

      }
      else  if (AlarmTone == 1) // Med Tone
      {
        if (SoundSequence < 6)
        {
          if (SoundSequence & 1)
          {
            tone(13, 1000, 300);
            NextAdvanceSound = millisCopy + 200;
            SoundSequence++;
          }
          else
          {
            NextAdvanceSound = millisCopy + 200;
            SoundSequence++;  
            noTone(13);  
            PORTD |= 32; // Turn off speaker    
          }

        }
        else
        { 
          NextAdvanceSound = millisCopy + 1400;
          SoundSequence = 0;
          noTone(13);
          PORTD |= 32; // Turn off speaker
        }

      }
      else  if (AlarmTone == 0) // High Tone
      {
        if (SoundSequence < 6) 
        {
          if (SoundSequence & 1)
          {
            tone(13, 2050, 400);
            NextAdvanceSound = millisCopy + 300;
            SoundSequence++;
          }
          else
          {
            NextAdvanceSound = millisCopy + 200;
            SoundSequence++;  
            noTone(13);  
            PORTD |= 32; // Turn off speaker    
          }

        }
        else
        { 
          NextAdvanceSound = millisCopy + 1000;
          SoundSequence = 0; 
          noTone(13);
          PORTD |= 32; // Turn off speaker
        }

      }
    }
  }




  if (LEDTestMode)
  {

    if (millisCopy > WordStopTime) {
      LEDTestStage++;
      byte atemp, btemp, ctemp;
      byte cpos = LEDTestStage / 18;  //(which char to use)

      if (cpos > 4){
        LEDTestStage = 0;
        cpos = 0;
      }

      byte dtemp = LEDTestStage - 18 * cpos;

      if (dtemp <= 7)
      {
        atemp = (1 << dtemp);
        btemp = 0;
        ctemp = 0;
      }
      else if (dtemp <= 9)
      {
        atemp = 0;
        btemp = (1 << (dtemp - 8));
        ctemp = 0;
      }
      else
      {
        atemp = 0;
        btemp = 0;
        ctemp = (1 << (dtemp - 10));
      }

      // Load buffers
      j = 0;
      while (j < 5)
      { 
        if (j == cpos)
        {
          bufl1[j] = atemp;
          bufh1[j] = btemp;
          bufh2[j] = ctemp;   
        }
        else
        {
          bufl1[j] = 0;
          bufh1[j] = 0;
          bufh2[j] = 0;   
        }
        j++;
      } 

      WordStopTime = millisCopy + 1000; // 100 ms per segment
      DisplayWordMode = 1;

    }
  }




  if (DisplayWordMode)
  {
    if (SerialDisplayMode == 0){
      if (millisCopy > WordStopTime)
        DisplayWordMode = 0;
    }

  }

  else if (OptionMode){

    if (OptionMode == 1) {  // AM-PM / 24 HR   

      if (HourMode24) 
        LoadCharBuffer("24 HR"); 
      else
        LoadCharBuffer("AM/PM");

      LoadShiftRegBuffers();
    }
    else if (OptionMode == 2)
    {
      if (OptionNameSequence == 0)
      {
        DisplayWordSequence("NIGHT",700);      
      }
      else if (OptionNameSequence == 1)
        DisplayWordSequence("     ",100);
      else if (OptionNameSequence == 2)
      {
        DisplayWordSequence("LIGHT",700);
      }
      else if (OptionNameSequence == 3)
        DisplayWordSequence("     ",100);
      else {
        if(  NightLightType == 0)
        {
          LoadCharBuffer(" NONE");
          LoadShiftRegBuffers(); 
        }
        else if(  NightLightType == 1)
        {
          LoadCharBuffer("LED_L");
          LoadShiftRegBuffers(); 
        }
        else if(  NightLightType == 2)
        {
          LoadCharBuffer("LED_H");
          LoadShiftRegBuffers(); 
        }

      }
    }
    else if (OptionMode == 3)
    {
      if (OptionNameSequence == 0)
      {
        DisplayWordSequence("ALARM",700); 
      }
      else if (OptionNameSequence == 1)
        DisplayWordSequence("     ",100);
      else if (OptionNameSequence == 2)
      {
        DisplayWordSequence("TONE ",700);
      }
      else if (OptionNameSequence == 3)
        DisplayWordSequence("     ",100);
      else {
        if(  AlarmTone == 0)
        {
          LoadCharBuffer(" HIGH");
          LoadShiftRegBuffers(); 
        }
        else if(  AlarmTone == 1)
        {
          LoadCharBuffer(" MED ");
          LoadShiftRegBuffers(); 
        }
        else if(  AlarmTone == 2)
        {
          LoadCharBuffer(" LOW ");
          LoadShiftRegBuffers(); 
        }
        else if(  AlarmTone == 3)
        {
          LoadCharBuffer("SIREN");
          LoadShiftRegBuffers(); 
        }

      }
    }
    else if (OptionMode == 4)
    {
      if (OptionNameSequence == 0)
      {
        DisplayWordSequence("TEST ",700);

      }
      else if (OptionNameSequence == 1)
        DisplayWordSequence("     ",100);
      else if (OptionNameSequence == 2)
      {
        DisplayWordSequence("SOUND",700); 
      }
      else if (OptionNameSequence == 3)
        DisplayWordSequence("     ",100);
      else{
        LoadCharBuffer("USE+-");
        LoadShiftRegBuffers(); 
      }
    }
  }
  else {

    if ((PINBcopy & 1) == 0){
      // Display Alarm time whenever "Alarm/Snooze" button is pressed. 
      CharacterBuffer[0] = (AMPM24HdisplayAlrm - asciiOffset);
      CharacterBuffer[1] = (MinAlrmOnes + numberOffset);
      CharacterBuffer[2] = (MinAlrmTens + numberOffset);
      CharacterBuffer[3] = (HrAlrmOnes + numberOffset);
      CharacterBuffer[4] = (HrAlrmTens + numberOffset);

      // Leading-Zero blanking for 12-hour mode:

      if (ZeroHourBlankAlrm)
        CharacterBuffer[4] = (' ' - asciiOffset);
    }
    else {
      // "Normal" time display: 
      CharacterBuffer[0] = (AMPM24HdisplayNow - asciiOffset);
      CharacterBuffer[1] = (MinNowOnes + numberOffset);
      CharacterBuffer[2] = (MinNowTens + numberOffset);
      CharacterBuffer[3] = (HrNowOnes + numberOffset);
      CharacterBuffer[4] = (HrNowTens + numberOffset);

      // Leading-Zero blanking for 12-hour mode:

      if (ZeroHourBlankNow)
        CharacterBuffer[4] = (' ' - asciiOffset);
    }

    LoadShiftRegBuffers();

    // Add time delimiter (colon) for time display, whether that's "real" time or the alarm.
    bufl1[2] |= 128;
    bufl1[3] |= 64;    

    if (AlarmEnabled)
      bufl1[4] |= 128;    // Upper left dot
  }

  // Time (or word) to display is now computed.
  // Now is the place in the loop when we switch gears, and 
  // actually light up the LEDs. :)

  refreshDisplay();


  // Can this sync be tried only once per second?
  if( getPCtime()) {  // try to get time sync from pc


    if(DateTime.available()) { // update clocks if time has been synced

      DisplayWordSequence("SYNC ",1000);
      // Set time to that given from PC.
      MinNow = DateTime.Minute;
      SecNow = DateTime.Second;
      HrNow = DateTime.Hour;

      //    if ( HrNow > 11)   // Convert 24-hour mode to 12-hour mode
      //    HrNow -= 12;     

      // Print confirmation
      Serial.print("Alpha Clock Five: Clock sync at: ");
      Serial.println(DateTime.now(),DEC);

      if ( prevtime != DateTime.now() )
      {
        if (ExtRTC) 
          RTCsetTime(HrNow,MinNow,SecNow);

        DateTime.available(); //refresh the Date and time properties
        digitalClockDisplay( );   // update digital clock
        prevtime = DateTime.now(); 
      }
    }
  } 

}


/*
Simple alternative loop , for testing brightness/refresh rates
 void loop()
 {   refreshDisplay();
 }
 */






