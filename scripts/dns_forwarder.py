import socket
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="UDP DNS Forwarder for Intranet Split-Brain DNS")
    parser.add_argument("--listen", default="::", help="Listen address (default: :: for all IPv6/IPv4 interfaces)")
    parser.add_argument("--port", type=int, default=53, help="Listen port (default: 53)")
    parser.add_argument("--upstream", required=True, help="Upstream DNS IP (The corporate VPN DNS IP, e.g. 10.x.x.x)")
    parser.add_argument("--upstream-port", type=int, default=53, help="Upstream DNS Port (default: 53)")
    
    args = parser.parse_args()

    # Create UDP sockets
    try:
        if ":" in args.listen:
            server_sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
        else:
            server_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        server_sock.bind((args.listen, args.port))
    except Exception as e:
        print(f"Failed to bind UDP {args.listen}:{args.port} - {e}")
        sys.exit(1)

    # We use IPv4 for the upstream corporate DNS typically
    client_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    client_sock.settimeout(5.0)

    print(f"[*] DNS Forwarder started.")
    print(f"[*] Listening on UDP [{args.listen}]:{args.port}")
    print(f"[*] Forwarding to UDP {args.upstream}:{args.upstream_port}")

    while True:
        try:
            # Receive UDP DNS query
            data, addr = server_sock.recvfrom(4096)
            
            # Forward query to upstream corporate DNS
            client_sock.sendto(data, (args.upstream, args.upstream_port))
            
            # Wait for response
            try:
                response, _ = client_sock.recvfrom(4096)
                # Send the response back to the original client
                server_sock.sendto(response, addr)
            except socket.timeout:
                print(f"[!] Upstream DNS {args.upstream} timed out.")
                continue

        except KeyboardInterrupt:
            print("\nShutting down.")
            break
        except Exception as e:
            print(f"[!] Error: {e}")

if __name__ == "__main__":
    main()
