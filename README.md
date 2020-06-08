# piaNetTest
Automatically test the network status of a Mac and either connect or disconnect PIA automatically.

## Requirements

This requires the latest version of the Private Internet Access VPN client and is meant as mostly an example / proof of concept.  It does work on my system but that is no gaurentee it will work on your system.

## Customization

The plist file for launchd is setup for my system and thus needs to be changed, I recommend putting the script in its own folder somewhere that your user account can write to that folder and then setting the working directory accordingly.  It is possible to put the script anywhere and use `~/.config` or some other standard for placing the needed files.

### PLIST File
This file is needed for launchd to execute the script on a regular basis.  The configuration does not execute the script upon loading, it'll wait 5 minutes and then execute every 5 minutes there after.  There are a lot of limitations of launchd, and perhaps chron would be a better way to do this.  I don't want to use cron because ASFAIK command in cron run even if you're not logged in and PIA won't accept commands if not logged in without changing to background mode.  Even then, it would saddle any other user on the system with PIA and no way to control it.  I just don't think it's a great option.  I really don't care for the fact that launchd won't allow Globbing anymore and thus the `~` can't be processed into a users HOME directory anymore.  I could change things to be in `/usr/local` but that's now how my system is setup and I'd have to write a sample launchd.  I'm just too lazy for that.

Anyone using this should change the **environment variables** to reflect their desired path arguments and home directory.  I've tried to use direct paths to programs wherever possible so it might be possible to omit them entirely.  I don't believe I rely on the HOME variable at all either.  They are included because that's the default template I use.

The snippet below shows what should be customized for environment variables.
```
	<key>EnvironmentVariables</key>
	<dict>
		<key>HOME</key>
		<string>/Users/cyclops</string>
		<key>PATH</key>
		<string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
	</dict>
 ```

The script's **location** and **working directory** will also need to be set.  I have a bit of a strange setup where I keep my scripts synced to iCloud, which is why the scripts location is strange.
```
	<array>
		<string>/bin/zsh</string>
		<string>/Users/cyclops/Library/Mobile Documents/com~apple~CloudDocs/Scripts/piaNetTest.sh</string>
	</array>
```

Now the script does give output when something changes.  The **standard out** and **standard error** log files are set to dump into my `~/Library/Log` directory.  It isn't much text but it can be helpful for diagnosing issues with execution.  This will also need to be set to wherever you want the files to go.  As far as I know, I can't use the standard `~` to represent my home directory and make all this easier so I just set it explicitely.
```
	<key>StandardErrorPath</key>
	<string>/Users/cyclops/Library/Logs/piaNetTest.log</string>
	<key>StandardOutPath</key>
	<string>/Users/cyclops/Library/Logs/piaNetTest.log</string>
```

Finally the **working directory** is going to be where the script expects to read and write to files it needs.  In particular there is the `piaNetTest.data` and `piaNetTest.trusted` files.  The first stores what the last change in network showed for a network name.  This is used to determine if further checks are needed.  The second stores the list of network names which are trusted, one per line.
```
	<key>WorkingDirectory</key>
	<string>/Users/cyclops/Library/Mobile Documents/com~apple~CloudDocs/Scripts</string>
```

I've had a lot of trouble getting launchd to use nice things like `~/` to set directory locations.  I could use `$HOME` once in the script, but I don't.  Once the PLIST file is configured, it can pretty much just stay that way so I don't personally see it as a big deal.  The launchd service is a right pain in the butt even though it is the way Mac's do things.

## Trusted Networks

As I said before, the trusted networks are stored in the scripts working directory in a file called `piaNetTest.trusted`.  The script expects the file to exist!  Even if you don't trust anyone or anything, just create an empty file.  The script will run without that but it will spit out a warning every time until it finds that file.

### Example
```
My-Network
My-Network-5G
iPhone-Hotspot
en3
```

Now, in theory you can use a network name that has spaces in it.  I don't have any networks that I use with spaces in the names so I can't test it.  However, using zsh it should parse one network name per line with spaces so long as it doesn't have other control characters in it (such as quotes, backslashes, or similar).  I don't know this for sure so your milage may vary.
