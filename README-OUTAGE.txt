OFFLINE AI KIT - QUICK CARD (no internet needed)
================================================

START   Windows: START-OFFLINE-AI.bat     Mac: START-OFFLINE-AI-MAC.command
        Browser opens:  Chat     (Windows: http://127.0.0.1:8091/chat.html,
                                  Mac: the chat.html file in the kit's www folder)
                        Library  http://127.0.0.1:8090/
STOP    Windows: STOP-OFFLINE-AI.bat      Mac: STOP-OFFLINE-AI-MAC.command
CHECK   Windows: STATUS.bat               Mac: STATUS-MAC.command

WHICH AI MODEL?
  On battery / need it fast ..... llama3.2:3b  or  phi4-mini
  Everyday questions ............ qwen3.5:9b   (default)
  Hard questions, plugged in .... qwen3:14b  or  gemma3:12b
  Medical questions ............. medgemma:4b  AND check the Library

IN THE LIBRARY (search box at the top)
  WikiMed / Wikipedia Medicine ... first aid, illness, medicines
  Post-disaster, Water, Food ..... survival, purifying water, storing food
  Knots, Appropedia, iFixit ...... practical fixes and repairs
  Wikipedia ...................... everything else (once its download finished)

SAVE POWER
  Close the chat tab when not using it. Use the small models.
  Dim the screen. Unplug anything you don't need.

SAFETY
  The AI can be wrong. Never trust it alone for medicine doses.
  Check the Library. Call emergency services (911 in North America)
  as soon as you can reach them.

IF SOMETHING DOESN'T WORK
  1. Run STOP-OFFLINE-AI.bat, then START-OFFLINE-AI.bat again.
  2. Restart the laptop and try again.
  3. Look in the "logs" folder (ollama*.log, kiwix*.log).
  4. Mac: if a .command won't open, open Terminal, type  bash  and a
     space, drag the file in, press Return.
