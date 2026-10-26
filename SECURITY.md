# Security and privacy

Steam sharing starts off. Private relay credentials are held in memory and are
not included in this repository or release. Names and Steam codes are self-reported;
they do not prove account ownership. See [server/PRIVACY.MD](server/PRIVACY.MD)
for relay data handling; the relay source in [server/](server/) can be reviewed directly.

The client ZIP contains no server credentials, databases, private messages,
full game archives or full game databases. Deployment of the relay needs
operator-managed secrets and configuration outside the web root.

Please report sensitive issues privately to the maintainer or through the host
repository's private security reporting channel. Do not post credentials, private
messages or live exploit details in public issues.
