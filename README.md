# eeg-labeler-rule-system

This script is for the EEG labeling collaboration project of the [polyphasic community](https://discord.gg/UJcbfby). It post-processes EEG graphs outputted from [Yinsei's Zeo screenshot reader](https://github.com/PolyphasicDevTeam/zeo-eeg-labeler) using the following abstract rules:

* Shift Light sleep within REM or SWS to closest edge
* REM ≤ 15m within SWS treated as SWS
* SWS ≤ 15m within REM treated as REM
* REM at start of recording is actually NREM1
* SWS at start of recording is actually Awake
* Wakes ≤ 15m within REM or SWS are are treated as REM or SWS
* Discard anything with an interrupted wake time of 20 minutes or more

### Example

#### Before

<p align="center">
  <img src="https://i.imgur.com/YTGAw4T.png" alt="(example of input)"/>
</p>

#### After

<p align="center">
  <img src="https://i.imgur.com/gva1uTh.png" alt="(example of output)"/>
</p>
