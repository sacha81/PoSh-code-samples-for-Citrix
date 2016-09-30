#checkdisplaymode.ps1
# info source https://www.citrix.com/blogs/2015/02/16/citrix-xendesktopxenapp-how-to-determine-hdx-display-mode/
 
#Remote:
#wmic /node:c99c0088.mobi.mobicorp.ch /namespace:\\root\citrix\hdx path citrix_virtualchannel_thi....
 
$displaymodeTable = @{}
$displaymode = "unknown"
 
 
 
#H264
$displaymodeTable.H264Active = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_thinwire get /value | findstr IsActive=*
 
    # H.264 Pure
            $displaymodeTable.Component_Encoder_DeepCompressionEncoder = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_thinwire get /value | findstr Component_Encoder=DeepCompressionEncoder
            #Component_Encoder=DeepCompressionV2Encoder
            if ($displaymodeTable.Component_Encoder_DeepCompressionEncoder -eq "Component_Encoder=DeepCompressionEncoder")
            {
            $Displaymode = "Pure H.264"
            }
           
 
            # Thinwire H.264 + Lossless (true native H264)
            $displaymodeTable.Component_Encoder_DeepCompressionV2Encoder = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_thinwire get /value | findstr Component_Encoder=DeepCompressionV2Encoder
            #Component_Encoder=DeepCompressionV2Encoder
            if ($displaymodeTable.Component_Encoder_DeepCompressionV2Encoder -eq "Component_Encoder=DeepCompressionV2Encoder")
            {
            $Displaymode = "H.264 + Lossless"
            }
           
            #H.264 Compatibility Mode (ThinWire +)
            $displaymodeTable.Component_Encoder_CompatibilityEncoder = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_thinwire get /value | findstr Component_Encoder=CompatibilityEncoder
            #Component_Encoder=CompatibilityEncoder
            if ($displaymodeTable.Component_Encoder_CompatibilityEncoder -eq "Component_Encoder=CompatibilityEncoder")
            {
            $Displaymode = "H.264 Compatibility Mode (ThinWire +)"
            }
           
           
            # Selective H.264 Is configured
            $displaymodeTable.Component_Encoder_Deprecated = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_thinwire get /value | findstr Component_Encoder=Deprecated
            #Component_Encoder=Deprecated
           
                        #fall back to H.264 Compatibility Mode (ThinWire +)
                        # Auf Receiver selective nicht geht:
                        $displaymodeTable.Component_VideoCodecUse_None = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_thinwire get /value | findstr Component_VideoCodecUse=None
                       
                        if ($displaymodeTable.Component_VideoCodecUse_None -eq "Component_VideoCodecUse=None")
                        {
                        $Displaymode = "Compatibility Mode (ThinWire +), selective H264 maybe not supported by Receiver)"
                        }
                       
                       
                        #Is used
                        $displaymodeTable.Component_VideoCodecUse_Active = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_thinwire get /value | findstr 'Component_VideoCodecUse=For actively changing regions'
                                              
                        if ($displaymodeTable.Component_VideoCodecUse_Active -eq "Component_VideoCodecUse=For actively changing regions")
                        {
                        $Displaymode = "Selective H264"
                        }
 
 
#Legacy Graphics
$displaymodeTable.LegacyGraphicsIsActive = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_graphics get /value | findstr IsActive=*
$displaymodeTable.Policy_LegacyGraphicsMode = wmic  /namespace:\\root\citrix\hdx path citrix_virtualchannel_graphics get /value | findstr Policy_LegacyGraphicsMode=TRUE
if ($displaymodeTable.LegacyGraphicsIsActive -eq "IsActive=Active")
            {
            $Displaymode = "Legacy Graphics"
            }
           
 
#DCR
$displaymodeTable.DcrIsActive = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_d3d get /value | findstr IsActive=*
$displaymodeTable.DcrAERO = wmic /namespace:\\root\citrix\hdx path citrix_virtualchannel_d3d get /value | findstr Policy_AeroRedirection=*
if ($displaymodeTable.DcrAERO -eq "Policy_AeroRedirection=TRUE")
            {
            $Displaymode = "DCR"
            }
 
$Displaymode
 
$displaymodeTable
Write-Host ""
Write-Host "Displaymode is $Displaymode"