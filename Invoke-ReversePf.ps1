function Invoke-ReversePortForward {
    param (
        [string]$RemoteHost = "YOUR.VPS.IP",
        [int]$RemotePort = 4444,
        [int]$LocalPort = 1080
    )

    $client = New-Object System.Net.Sockets.TcpClient
    $client.Connect($RemoteHost, $RemotePort)
    $remote = $client.GetStream()

    $listener = [System.Net.Sockets.TcpListener]::new("127.0.0.1", $LocalPort)
    $listener.Start()

    while ($true) {
        $localClient = $listener.AcceptTcpClient()
        $localStream = $localClient.GetStream()

        Start-Job {
            $buffer = New-Object byte[] 8192
            while (($count = $localStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $remote.Write($buffer, 0, $count)
            }
            $localStream.Close()
        }

        Start-Job {
            $buffer = New-Object byte[] 8192
            while (($count = $remote.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $localStream.Write($buffer, 0, $count)
            }
            $remote.Close()
        }
    }
}
