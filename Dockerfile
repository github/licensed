FROM ruby:3.2
WORKDIR /app
# cmake pkg-config needed for ffi
RUN apt-get update && apt-get install -y build-essential cmake pkg-config
# Copy the rest of the application code
COPY . /app
# RUN script/bootstrap
# RUN RUN gem build licensed.gemspec
# RUN gem install licensed-*.gem
RUN gem install licensed -v 4.4.0
# Set the entrypoint to run licensed
ENTRYPOINT ["licensed"]