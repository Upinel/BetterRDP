# UpinelBetterRDP Optimization Settings

The `UpinelBetterRDP.reg` is a Windows Registry file that is designed to enhance your Remote Desktop Protocol (RDP) session by enabling 60FPS, GPU acceleration, and RemoteFx features. These optimizations aim to provide a smoother and more responsive remote desktop experience.

## Disclaimer

Modifying the Windows Registry can potentially cause system instability if not done correctly. It is highly recommended that you **backup your system and registry** before applying these changes. Use these registry settings at your own risk.

## Features Included

- Allows both GPU acceleration and RemoteFx during RDP sessions.
- Sets the capture framerate to 60 FPS for a smoother visual experience.
- Reduces compression to improve image quality over RDP.
- Adjusts system responsiveness for an enhanced user interface interaction.
- Disables bandwidth throttling to reduce network-related slowdowns.
- Allows for large MTU packets, which can improve network performance.
- Optimizes the flow control for display and channel bandwidth (RemoteFX devices, including controllers).
- Removes artificial latency delay for more immediate interaction over RDP.
- Option to disable WDDM drivers in favor of XDDM drivers for better performance on Nvidia graphics cards (commented out by default).

## How to Use

To apply these optimizations:

1. Download the `UpinelBetterRDP.reg` file from this repository.
2. Backup your current registry settings.
3. Double-click the `UpinelBetterRDP.reg` file.
4. Confirm that you want to apply the changes by clicking 'Yes' when prompted.
5. Reboot your computer for the changes to take effect.

## Support

- For Windows 8, Windows 10, and Windows Server 2012 or later.
- It is advisable to perform these changes on machines where you have full permissions and control.
- It is always better to test the settings on a non-production machine before applying them to a live environment.

## Contributions

Your contributions are welcome! If you have improvements or additional tweaks, please fork the repository and submit a pull request.

## Contact & Feedback

If you encounter any issues or have suggestions, please open an issue within the GitHub repository.

## License

These settings are provided "as is", with no warranties, and confer no rights. You are responsible for using these settings safely and within the terms of your software licensing agreements.

## Acknowledgments

Credit to the various sources and community contributions from which these settings have been derived:

- [Microsoft Support](https://support.microsoft.com/en-us/help/2885213/frame-rate-is-limited-to-30-fps-in-windows-8-and-windows-server-2012-r)
- [Reddit Windows 10 Optimization Guide](https://www.reddit.com/r/killerinstinct/comments/4fcdhy/an_excellent_guide_to_optimizing_your_windows_10/)


## License
This project is open source and available under the Apache 2.0 License.

## Buy me a coffee
If you wish to donate us, please donate to [https://paypal.me/Upinel](https://paypal.me/Upinel), it will be really lovely.

Enjoy a better Remote Desktop experience!
