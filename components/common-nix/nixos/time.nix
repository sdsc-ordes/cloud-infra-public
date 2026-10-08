{ config, ... }:
{
  time = {
    timeZone = config.settings.timezone;
  };
}
