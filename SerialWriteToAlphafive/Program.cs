using System;
using System.IO.Ports;
using System.Text;

class Program
{
    static void Main(string[] args)
    {
        send(args);
    }

    /*
     * This method sends a command and message to an Arduino over a serial port.
     * The packet structure is as follows:
     * [Header (1 byte)] [Command (2 bytes)] [Message Length (1 byte)] [Message (variable length)]
     * 
     * The header is fixed at 0xFF, the command is "A1", and the message is built from the command-line arguments.
     * The method opens the serial port, sends the header, waits briefly, then sends the command and message as a single packet.
     * You can use uppercase or lower case letters, but the message will be converted to uppercase for consistency.
     * The method also includes error handling and ensures the port is closed properly.
     */
    public static void send(string[] args) 
    {
        //You may need to change the COM port name and baud rate to match your Arduino/USB settings
        SerialPort port = new SerialPort("COM7", 9600, Parity.None, 8, StopBits.One);

        try
        {
            port.Open();

            // Build the full packet in one byte array
            byte header = 0xFF; // Start byte
            string command = "A1";
            string message = string.Join(" ", args);
            message = message.ToUpper(); // Convert message to uppercase for consistency
            // Allocate final buffer

            byte[] commandPlusMessage = new byte[] { Encoding.ASCII.GetBytes(command)[0], Encoding.ASCII.GetBytes(command)[1], (byte)message.Length };

            foreach (char c in message)
            {
                commandPlusMessage = commandPlusMessage.Append((byte)c).ToArray();
            }

            port.Write(new byte[] { header }, 0, 1); // Send header first
            Thread.Sleep(1000); // Short delay to ensure header is processed
            if (port.IsOpen)
                port.Close();
            /*
            * NOTE: 
            * For some reason I ran into an issue where I had to call the program from the command line
            * twice before the clock would pick it up, so I close the port and reopen it to send the rest 
            * of the data.
            */
            port.Open();
            port.Write(commandPlusMessage, 0, commandPlusMessage.Length);
            foreach (string arg in args)
            {
                Console.WriteLine("Argument: " + arg);
            }
            Console.WriteLine("CommandPlusMessage: " + BitConverter.ToString(commandPlusMessage) + " Length: " + commandPlusMessage.Length);
            Console.WriteLine("Message Length: " + message.Length);
            Console.WriteLine("Packet sent.");
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error: " + ex.Message);
        }
        finally
        {
            if (port.IsOpen)
                port.Close();
        }
    }
}
