FROM ruby:3.2.2

# Create a non-root user to run the app
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN mkdir -p /home/appuser && chown -R appuser:appuser /home/appuser

# Set the working directory
WORKDIR /home/appuser

# Install dependencies
RUN apt-get update && apt-get install -y \
  build-essential \
  tzdata

# Copy the rest of the app
COPY . /app

# Set the ownership of the app files to the non-root user
RUN chown -R appuser:appuser /home/appuser

# Switch to the non-root user
USER appuser
WORKDIR /app

# Start the app
CMD ruby server.rb
