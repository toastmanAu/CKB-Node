# CKB-Node
Guide to build a CKB node using an Orange Pi 3B

Orange Pi 3b Ubuntu 22.04 XFCE Custom Node Image and Guide
https://drive.google.com/drive/folders/1HcHqw6diSt8tZUwNw4w6q0revqnInk0n?usp=sharing

Notes: 
1) The above image is preconfigured to output the Opi3B's display to the DSI port, as a result of the available device overlay configuration this disables the HDMI output. If you wish to run this computer on a larger screen via HDMI you will need to disable the DSI display via the "orangepi-config" application.
2) The STL files were designed to be printed on a Bambu Lab X1C printer, while any 3D printer can be used there are a couple things to note. Firstly, the printed designs you may have seen have been multi-coloured. This was achieved in conjunction with Bambu labs AMS, multi spool sytem, which i then manually asigned colours to the models during the slicing process. The STL files don't different colour and the allocation of these colours is up to you and your own artistic interpretation. All the pieces except the steampunk style face and panels were designed to be coloured by layer height for improved efficiency through minimised filament changes (Anyone with a multi spool system knows what i mean:)). Any similar multi spool system will no doubt work the same. For those not fortunate enough to own a multi colour system i apologise as i to not currently have separate individually printed stl files to simplify your printing process, you are welcome to modify the files to suit your own needs if you have the skills. The Second thing to note is the Bambu Labs X1C has very precise printing. The tolerance gaps for the printed parts/panels vary from 0.05mm to 0.1mm and allow for adhesive free panel exchange. Your printer may require wider tolerances to have the desired effect. I suggest printing the Main body first and possibly test printing some part of the panels to test tolerances before commiting to the full print. The base component holds the screen snugly in place of thew body and if it doesn't fit well you may need to use some superglue to hold it in place. I printedf my parts in PLA+ material but you are free to use what you like, again tolerances for friction fitting parts vary here.   


CKB Node Parts List

Orange Pi 3B 8GB+256G EMMC Module+5V3A Type-C Power Supply
https://a.aliexpress.com/_mtsnkO4

5 inch TFT LCD Display Capacitive Touch Screen DSI Connector 800x480
https://a.aliexpress.com/_mttBpfS

Heat Sink Set Metal Copper Heatsink Passive Cooling Pad 
https://a.aliexpress.com/_m0l0tb2

DC5V  3010 30MM 30*30*10MM Cooling Fan Hydraulic Bearing Ball Bearing 2pin
https://a.aliexpress.com/_mLKDkuY

JST PH 1.25mm Wire cable Connector 2 PIN male and female plug Socket
(Make sure you choose 1.25mm 2pin)
https://a.aliexpress.com/_mKi6gp2

Also Recommended Wireless USB keyboard and mouse

To Update CKB version via script.


If the node is running close it. Best to focus the terminal window and press “ctrl+c” and wait for a graceful shutdown. 

Now open Firefox which is in the applications->internet menu.

Go to 

https://github.com/toastmanAu/CKB-Node/blob/main/update_ckb.sh

Hit download.

Firefox should ask where you want to save to best put it in the “home\orangepi\ckb”folder. If it doesn’t ask where you want to save it’ll just go to   ~\Downloads. Once downloaded close Firefox 

Press “ctrl+t” to bring up a new terminal window. 

If Firefox didn’t ask first write

sudo cp ~\Downloads\update_ckb.sh ~\ckb

Press enter

If it did and it’s already in that folder skip that. 

Next either write each line then press enter or copy and paste the following

cd ckb
sudo chmod +x ./update_ckb.sh
sudo ./update_ckb.sh

It will ask you which version you want to install the most recent version is 

0.201.0 

Write that and press enter. It’ll then download the files and confirm the installed version. 

Now restart the node.
