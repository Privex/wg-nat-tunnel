# NAT Tunnel between two servers FRONT and BACK

This set of configs/scripts was created by Someguy123 @ Privex Inc.

```
├── back
│   └── wg0.conf
├── front
    ├── config.env
    ├── down.sh
    ├── up.sh
    └── wg0.conf
```

In this repo, are configs and scripts for setting up a Wireguard tunnel between two servers,
with NAT in both directions to forward traffic to/from the `FRONT` server.

The wireguard configs come with private + public keys preloaded, you may want to re-generate
them using `wg genkey | tee wg0-privkey | wg pubkey > wg0-pubkey` for FRONT and BACK, then
paste the keys into wg0.conf on each server (remember to copy the public key into `[peer]` on
the opposite server - i.e. FRONT's pubkey in BACK's peer config and vice versa)

This script also allows you to exclude ports on `FRONT`, so that they go directly to `FRONT` instead
of being proxied to `BACK`. By default, 22 and 2222 are excluded so that you can still access
SSH on FRONT, you can adjust this in `config.env` under `EXCL_PORTS`.

WARNING: We strongly recommend making sure you have IPv6 setup on the `BACK` server, as the VPN
will make `BACK`'s real IPv4 inaccessible, but IPv6 should still work, so you can use IPv6 in order
to get into SSH on `BACK`.


## Setting up the BACK server

The `BACK` server is the server which you want to protect/hide, all of it's traffic will be
tunneled to/from the IP of the `FRONT` server.

WARNING: We strongly recommend making sure you have IPv6 setup on the `BACK` server, as the VPN
will make `BACK`'s real IPv4 inaccessible, but IPv6 should still work, so you can use IPv6 in order
to get into SSH on `BACK`.

This is the easiest to setup, as it simply uses plain Wireguard.

Install wireguard:

```
apt update
apt install -y wireguard
```

Copy the contents of `back/wg0.conf` from this repo, into `/etc/wireguard/wg0.conf` on the BACK server, then open it up and replace `1.1.1.1` with the external IPv4 address of your `FRONT` server:

```
nano /etc/wireguard/wg0.conf
```

Fix the permissions, otherwise wireguard will complain:

```
chmod 700 /etc/wireguard/wg0.conf
```

Enable wireguard on boot and start wireguard (WARNING: If you're connected to SSH via IPv4 you will be kicked out!):

```
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

Wireguard should now be started, so now we can move on to the `FRONT` server.

## Setting up the FRONT server

The `FRONT` server is the server which will be "in front" of the `BACK` server, all traffic to and from `BACK` will go through the `FRONT` server and use it's external IP

Install wireguard:

```
apt update
apt install -y wireguard
```

Copy the contents of `front/wg0.conf` from this repo, into `/etc/wireguard/wg0.conf` on the FRONT server, then open it up and replace `2.2.2.2` with the external IPv4 address of your `BACK` server:

```
nano /etc/wireguard/wg0.conf
```

Fix the permissions, otherwise wireguard will complain:

```
chmod 700 /etc/wireguard/wg0.conf
```

Copy `config.env`, `up.sh`, and `down.sh` from the `/front/` folder inside this repo and put them inside of `/etc/wireguard/` on this FRONT server with the same name

```
nano /etc/wireguard/up.sh
nano /etc/wireguard/down.sh
nano /etc/wireguard/config.env
```

Make `up.sh` and `down.sh` executable:

```
chmod +x /etc/wireguard/{up,down}.sh
```

Open up `config.env` on the FRONT server and update `MY_IP` - replace it's value with `FRONT`'s external IPv4 (the main IP on eth0 or whatever it's primary interface is)

You can also adjust `EXCL_PORTS` if desired, these are ports which won't be forwarded to `BACK`, and instead will just go directly to `FRONT`. By default, port 22 and 2222 are excluded to allow you to use SSH on the FRONT server.

```
nano /etc/wireguard/config.env
```

Enable wireguard on boot and start wireguard (WARNING: If you're connected to SSH via IPv4 you may be kicked out!):

```
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

Now it should all be setup! :)

Time to do some tests!

## Verifying that it's working

Connect to your `BACK` server's SSH - you'll likely need to connect via IPv6 or via your server host's console.

### Test outgoing connection

Run this command to test outgoing IPv4 connectivity:

```
curl -4 https://myip.vc/index.txt
```

If outgoing connectivity is working okay, you'll see `FRONT`'s external IP listed in the output, instead of `BACK`'s IP

Be aware: some outgoing traffic may still go out via IPv6 unprotected, if you don't want this to happen, you'll need to either restrict your IPv6 routing so that it only routes IPv6 to the IP you're using to manage the server, or disable IPv6 (but if you disable IPv6 you'll only be able to manage the server via your host's console)

### Test incoming connection

First you'll need to install netcat before you can do either test:

```
apt install -y netcat
```

#### Option 1 - Test with a browser

If you're managing your server from a Windows computer, the easiest option is to test it using a browser.

First, run this command on `BACK`'s console:

```
nc -l 80
```

It'll show nothing at first, and may look like it's hanged, but it's perfectly normal, don't worry.

Now, while that's running in your console, open up your web browser on your home computer, and browse to `http://FRONT_IP` - where `FRONT_IP` is the external IPv4 address of `FRONT`

It won't load in your browser, however, after trying to load the URL, if you check back on your console, you should hopefully see a bunch of HTTP headers in your console:

```
root@ak-back:~# nc -l 80
GET / HTTP/1.1
Host: 138.68.152.xxx
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:109.0) Gecko/20100101 Firefox/115.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
Accept-Language: en-GB,en;q=0.5
Accept-Encoding: gzip, deflate
DNT: 1
Connection: keep-alive
Upgrade-Insecure-Requests: 1
Sec-GPC: 1
```

If you see something that looks like the above - then your incoming connectivity is working, and FRONT is properly forwarding traffic to BACK! :)

You can now hit CTRL-C in the console to exit netcat.

#### Option 2 - Test from a terminal

If you prefer, you can test it from a terminal instead!

First, run netcat on `BACK` - this command will listen on port 23 (telnet) for any incoming data:

```
nc -l 23
```

Now, from your home computer, open up a terminal (command prompt) and run this:

```
telnet FRONT_IP
```

Replace `FRONT_IP` with `FRONT`'s external IP address

Wait 2-3 seconds to ensure it's connected, then start typing something and hit enter, e.g.

```
hello
world

```

You should now see what you typed appear on `BACK`'s console!

If you did, then incoming connectivity is working!

## Finished!

You should be all setup now.

Be aware, at the time of writing, this does NOT tunnel IPv6 - which is intentional, so that you have
another method to connect to FRONT/BACK while the IPv4 is being tunneled. However, this means outgoing traffic on BACK may go via IPv6 directly, not through FRONT. If you want to avoid IPv6 leaks, you can either adjust the IPv6 routes so that it only knows to route to your home/work IPv6, or disable IPv6 and manage it through your host's console. Alternatively if you're more technically inclined, you could adjust the wireguard and iptables rules in the up/down.sh files to handle IPv6.

This set of configs/scripts was created by Someguy123 @ Privex Inc.

## [Buy a server from PRIVEX.IO starting from just 99 cents per month!](https://www.privex.io)


