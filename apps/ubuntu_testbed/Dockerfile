FROM ubuntu:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
  curl \
  dnsutils \
  iputils-ping \
  jq \
  net-tools \
  nmap \
  traceroute \
  ufw \
  wget
RUN apt install -y debian-keyring debian-archive-keyring apt-transport-https
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
RUN apt update
RUN apt install caddy

# Create a non-root user to run the app
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN mkdir -p /home/appuser && chown -R appuser:appuser /home/appuser

# Set the working directory
WORKDIR /home/appuser

# Copy the rest of the app
COPY . /app

# Set the ownership of the app files to the non-root user
RUN chown -R appuser:appuser /home/appuser


# Allow HTTP traffic through the firewall
RUN ufw allow 8080/tcp

# Switch to the non-root user
USER appuser
WORKDIR /app

# Start the webserver
CMD caddy file-server --listen :8080
