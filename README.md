## Commit `9c90e44`
All the updates I made to the v1.0 firmware are included in this commit.

https://github.com/hulsedavidj-collab/Alphafive1.0-ScrollingSerialInput/commit/9c90e44d23f6f822db61474b0ab1880920b401e9

## Commit `ac4f67e`
This commit contains the C# program I used to test the commands I implemented. Once you build the .exe you can pass command line arguments in the console and if you have things configured correctly you will see the clock LEDs display your input as a scrolling marquee.

https://github.com/hulsedavidj-collab/Alphafive1.0-ScrollingSerialInput/blob/ac4f67e9cdf8ae092aa186d5d95765ea75c6e5a6/SerialWriteToAlphafive/Program.cs

## Notes
I updated the baud rate on line 1187 of the `alphaclock_18_Rev1_0.pde` file

You may need to change the baud rate back to 19200.

I changed it to 9600 so I can route my commands through a TTL UART BLE breakout board device I bought on Amazon:

https://www.amazon.com/DSD-TECH-CC2640R2F-Bluetooth-Compatible/dp/B07N1FWQYP/ref=sr_1_2?crid=2LBGRAW31YYAB&dib=eyJ2IjoiMSJ9.RDFhPd8IK5ITNL4YDVe3LR0Ta3PubnwXwp0vB3Lpinc.w1nRsRBgH3rMfCV3kRtFa8LpWGpFPfgTiBI3m0taWfs&dib_tag=se&keywords=HM-18+ble&qid=1776557041&sprefix=hm-18+ble%2Caps%2C126&sr=8-2

## Credit
I did not create the Alpha Clock Five or the firmware, I am just a contributor. 

Windell Oskay from Evil Mad Scientist is the creator. https://www.evilmadscientist.com/

<img src="https://github.com/hulsedavidj-collab/Alphafive1.0-ScrollingSerialInput/blob/main/clock.jpg?raw=true" alt="Alpha Clock Five Red Edition" width="400" height="300"/>
