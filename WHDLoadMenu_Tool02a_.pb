;- ### Program Info ###
;
; WHDLoadMenu Tool
;
; Version 0.2a
;
; © 2022 Paul Vince (MrV2k)
;
; https://easymame.mameworld.info
;
; [ PB V5.7x/V6.x / 32Bit / 64Bit / Windows / DPI ]
;
; A converter for WHDLoadMenu prefs files.
;
;- ### Version Info ###
;
; ====================================================================
;
; Version 0.1a
;
; Initial Release
;
; ====================================================================
;
; Version 0.2a
;
; Fixed bug if game folders are in the root of the drive path
; Added ability to save in different cases
; Added FTP based data file download function to Fix_List procedure.
; Added FTP based genres download function to Fix_List procedure.
; Sped up CSV loading times.
; Sped up database loading times.
; Sped up list drawing procedure.
; Sped up filter and improved it's logic.
; Added Title Case to the help window.
; Changed 'Output Case' to 'Title Case' and renamed 'Ignore' to 'Camel Case' in the combobox.
; Sped up edit window drawing
; Added basic data to unknown slaves
; Added database error check to fix list procedure;

; ====================================================================
;
;- ### Enumerations ###

EnableExplicit

Enumeration
  #REGEX
  #DIR
  #MAIN_WINDOW
  #MAIN_LIST
  #LOAD_BUTTON
  #SAVE_BUTTON
  #FIX_BUTTON
  #CLEAR_BUTTON
  #HELP_BUTTON
  #TAG_BUTTON
  #UNDO_BUTTON
  #HELP_WINDOW
  #LOADING_WINDOW
  #LOADING_TEXT
  #HELP_EDITOR
  #SHORT_NAME_CHECK
  #DUPE_CHECK
  #UNKNOWN_CHECK
  #FTP
  #EDIT_WINDOW
  #EDIT_NAME
  #EDIT_SHORT
  #EDIT_SLAVE
  #EDIT_ICON
  #CASE_COMBO
EndEnumeration

;- ### Structures ###

Structure UM_Data
  UM_Name.s
  UM_Path.s
  UM_Genre.s
  UM_Slave.s
  UM_Short.s
  UM_Icon.s
  UM_Folder.s
  UM_Filtered.b
  UM_Unknown.b
EndStructure

Structure Comp_Data
  C_Name.s
  C_Short.s
  C_Slave.s
  C_Folder.s
  C_Genre.s
  C_Icon.s
EndStructure

;- ### Lists ###

Global NewList UM_Database.UM_Data()
Global NewList Undo_Database.UM_Data()
Global NewList Comp_Database.Comp_Data()
Global NewList Filtered_List.i()
Global NewMap Comp_Map.i()

;- ### Global Variables ###

Global Version.s="0.2a"
Global FTP_Folder.s="~Uploads"
Global FTP_SubFolder.s="mrv2k"
Global FTP_SubFolder2.s="IG_Tool"
Global FTP_Server.s="grandis.nu"
Global FTP_User.s="ftp"
Global FTP_Pass.s="amiga"
Global FTP_Passive=#True
Global FTP_Port=21
Global UM_Data_File.s=""
Global Keep_Data.b=#True
Global Short_Names.b=#False
Global Filter.b=#False
Global Unknown.b=#False
Global event, gadget, close.b
Global Name.s, CSV_Path.s
Global Home_Path.s=GetCurrentDirectory()
Global Prefs_Type=0
Global Output_Case.i=0

;- ### Macros ###

Macro Pause_Window(window)
  SendMessage_(WindowID(window),#WM_SETREDRAW,#False,0)
EndMacro

Macro Resume_Window(window)
  SendMessage_(WindowID(window),#WM_SETREDRAW,#True,0)
  RedrawWindow_(WindowID(window),#Null,#Null,#RDW_INVALIDATE)
EndMacro

Macro Message_Window(message)
  OpenWindow(#LOADING_WINDOW,0,0,150,50,message,#PB_Window_Tool|#PB_Window_WindowCentered,WindowID(#MAIN_WINDOW))
  TextGadget(#LOADING_TEXT,10,12,130,25,"Please Wait...", #PB_Text_Center)
EndMacro

Macro Backup_Database(state)
  
  CopyList(UM_Database(),Undo_Database())
  DisableGadget(#UNDO_BUTTON,state)
  
EndMacro

Macro DB_Filter(bool)
  
  ForEach UM_Database()
    If UM_Database()\UM_Filtered=bool
      AddElement(Filtered_List())
      Filtered_List()=ListIndex(UM_Database())
    EndIf
  Next
  
EndMacro

Macro Pause_Gadget(gadget)
  SendMessage_(GadgetID(gadget),#WM_SETREDRAW,#False,0)
EndMacro

Macro Resume_Gadget(gadget)
  SendMessage_(GadgetID(gadget),#WM_SETREDRAW,#True,0)
  InvalidateRect_(GadgetID(gadget), 0, 0)
  UpdateWindow_(GadgetID(gadget))
EndMacro

;- ### Procedures ###

Procedure.l FTPInit() 
  ProcedureReturn InternetOpen_("FTP",#INTERNET_OPEN_TYPE_DIRECT,"","",0) 
EndProcedure 

Procedure.l FTPConnect(hInternet,Server.s,User.s,Password.s,port.l) 
  ProcedureReturn InternetConnect_(hInternet,Server,port,User,Password,#INTERNET_SERVICE_FTP,0,0) 
EndProcedure 

Procedure.l FTPDir(hConnect.l, List FTPFiles.s()) 
  Protected hFind.l, Find.i
  Protected FTPFile.WIN32_FIND_DATA
  
  hFind=FtpFindFirstFile_(hConnect,"*.*",@FTPFile.WIN32_FIND_DATA,0,0) 
  If hFind 
    Find=1 
    While Find 
      Find=InternetFindNextFile_(hFind,@FTPFile) 
      If Find
        AddElement(FTPFiles())
        FTPFiles()=PeekS(@FTPFile\cFileName) ;Files
      EndIf      
    Wend
    InternetCloseHandle_(hFind) 
  EndIf 
EndProcedure 

Procedure.l FTPSetDir(hConnect.l,Dir.s) 
  ProcedureReturn FtpSetCurrentDirectory_(hConnect,Dir) 
EndProcedure 

Procedure.l FTPDownload(hConnect.l,Source.s,Dest.s) 
  ProcedureReturn FtpGetFile_(hConnect,Source,Dest,0,#FILE_ATTRIBUTE_NORMAL,#FTP_TRANSFER_TYPE_BINARY,0) 
EndProcedure 

Procedure.l FTPClose(hInternet.l) 
    ProcedureReturn InternetCloseHandle_(hInternet) 
EndProcedure 
 
Procedure Save_CSV()
  
  Protected igfile, output$, path.s, response
  
  path=""
  
  If FileSize(CSV_Path)>-1
    response=MessageRequester("Warning","Overwrite Old Game List?"+Chr(10)+"Select 'No' to create a new file.",#PB_MessageRequester_YesNoCancel|#PB_MessageRequester_Warning)
    Select response
      Case #PB_MessageRequester_Yes : path=CSV_Path
      Case #PB_MessageRequester_No : path=SaveFileRequester("New File", "", "Prefs File (*.prefs)|*.prefs",0)
    EndSelect 
  EndIf
  
  If GetExtensionPart(path)<>"prefs" : path+".prefs" : EndIf
  
  If response<>#PB_MessageRequester_Cancel And path<>""
    If CreateFile(igfile, path,#PB_Ascii)     
      ForEach UM_Database()
        output$=""
        If Short_Names
          output$+UM_Database()\UM_Short+"="
        Else
          output$+UM_Database()\UM_Name+"="
        EndIf
        If Output_Case=1  : output$=LCase(output$) : EndIf
        If Output_Case=2  : output$=UCase(output$) : EndIf
        If UM_Database()\UM_Slave<>"" : output$+UM_Database()\UM_Path+UM_Database()\UM_Slave : EndIf
        If UM_Database()\UM_Icon<>"" : output$+UM_Database()\UM_Path+UM_Database()\UM_Icon : EndIf
        If ListIndex(UM_Database())<ListSize(UM_Database()) : WriteString(igfile,output$+#LF$) : Else : WriteString(igfile,output$) : EndIf
      Next
      FlushFileBuffers(igfile)
      CloseFile(igfile)  
    EndIf
  EndIf
  
EndProcedure

Procedure Load_CSV()

  Protected CSV_File.i, Text_Data.s, Text_String.s
  Protected Count.i, I.i, Backslashes.i, Text_Line.s, Test_Line.s
  
  CSV_Path=OpenFileRequester("Open Prefs","WHDLoadMenu.prefs","Prefs File (*.prefs)|*.prefs",0)
  
  Protected NewList CSV_List.s()
  
  If CSV_Path<>""
    
    If ReadFile(CSV_File,CSV_Path,#PB_UTF8)
      
      Message_Window("Loading Game List...")
      
      Repeat
        AddElement(CSV_List())
        CSV_List()=ReadString(CSV_File)
        If Not FindString(CSV_List(),"=") 
          MessageRequester("Error", "Not a valid prefs file!",#PB_MessageRequester_Error|#PB_MessageRequester_Ok)
          CloseFile(CSV_File)
          CloseWindow(#LOADING_WINDOW)
          DisableGadget(#FIX_BUTTON,#True)
          DisableGadget(#SAVE_BUTTON,#True)
          DisableGadget(#CLEAR_BUTTON,#True)
          DisableGadget(#TAG_BUTTON,#True)
          DisableGadget(#DUPE_CHECK,#True)
          DisableGadget(#SHORT_NAME_CHECK,#True)
          DisableGadget(#DUPE_CHECK,#True)
          Short_Names=#False
          Filter=#False
          Unknown=#False
          SetGadgetState(#SHORT_NAME_CHECK,Short_Names)
          SetGadgetState(#DUPE_CHECK,Filter)
          SetGadgetState(#UNKNOWN_CHECK,Unknown)
          Break
        EndIf
      Until Eof(CSV_File)
      CloseFile(CSV_File)
      
      If ListSize(CSV_List())=0
        
        Goto Proc_Exit
        
      Else
        
        Count=CountString(Text_Data,#LF$)
        
        ClearList(UM_Database())
        
        SelectElement(CSV_List(),0)
        
        Test_Line=CSV_List()
        
        Prefs_Type=0
        
        If LCase(GetExtensionPart(StringField(Test_Line,2,"=")))="slave" : Prefs_Type=1 : SetGadgetItemText(#MAIN_LIST,-1,"Slave",1) : EndIf
        If LCase(GetExtensionPart(StringField(Test_Line,2,"=")))="info" : Prefs_Type=2 : SetGadgetItemText(#MAIN_LIST,-1,"Icon",1) : EndIf
        
        If Prefs_Type=0 : MessageRequester("Error","Not a valid prefs file!",#PB_MessageRequester_Error|#PB_MessageRequester_Ok) : Goto Proc_Exit : EndIf
        
        ForEach CSV_List()
          AddElement(UM_Database())
          Text_Line=CSV_List()
          UM_Database()\UM_Name=StringField(Text_Line,1,"=")
          UM_Database()\UM_Path=GetPathPart(StringField(Text_Line,2,"="))
          UM_Database()\UM_Genre=""
          If CountString(UM_Database()\UM_Path,"/")>1
            Backslashes=CountString(UM_Database()\UM_Path,"/")
            UM_Database()\UM_Folder=StringField(UM_Database()\UM_Path,Backslashes,"/")
          Else
            Backslashes=CountString(UM_Database()\UM_Path,":")
            UM_Database()\UM_Folder=StringField(UM_Database()\UM_Path,Backslashes+1,":")
            UM_Database()\UM_Folder=RemoveString(UM_Database()\UM_Folder,"/")
          EndIf
          If Prefs_Type=1 : UM_Database()\UM_Slave=GetFilePart(StringField(Text_Line,2,"=")) : EndIf
          If Prefs_Type=2 : UM_Database()\UM_Icon=GetFilePart(StringField(Text_Line,2,"="))  : EndIf
          UM_Database()\UM_Filtered=#False
        Next
        
        DisableGadget(#FIX_BUTTON,#False)
        DisableGadget(#SAVE_BUTTON,#False)
        DisableGadget(#CLEAR_BUTTON,#False)
        DisableGadget(#TAG_BUTTON,#False)
        DisableGadget(#DUPE_CHECK,#False)
        
        CloseWindow(#LOADING_WINDOW)
      EndIf
      
    EndIf
    
  Else
    MessageRequester("Error", "No File Selected!", #PB_MessageRequester_Error|#PB_MessageRequester_Ok)
  EndIf  
  
  SortStructuredList(UM_Database(),#PB_Sort_Ascending|#PB_Sort_NoCase,OffsetOf(UM_Data\UM_Name),TypeOf(UM_Data\UM_Name))

  Backup_Database(#True)
  
  Proc_Exit:
  
  FreeList(CSV_List())
  
EndProcedure

Procedure Filter_List()
   
  Protected Previous.s
  
  ClearList(Filtered_List())
  
  ForEach UM_Database()  
    UM_Database()\UM_Filtered=#False
    If Filter
      If UM_Database()\UM_Name=Previous   
        UM_Database()\UM_Filtered=#True
        PreviousElement(UM_Database())
        UM_Database()\UM_Filtered=#True
        NextElement(UM_Database())
      EndIf     
      previous=UM_Database()\UM_Name
    EndIf
    If Unknown
      If UM_Database()\UM_Unknown=#True
        UM_Database()\UM_Filtered=#True
      EndIf
    EndIf
  Next
  
  DB_Filter(#True)
    
EndProcedure

Procedure Get_Database()
  
  Protected hInternet.l, hConnect.l 
  Protected NewList FTP_List.s()
  Protected Old_DB.s, New_DB.s, Genres.s

  ExamineDirectory(#DIR,Home_Path,"*.*")
  
  CreateRegularExpression(#REGEX,"UM_Data") 
  
  While NextDirectoryEntry(#DIR)
    If DirectoryEntryType(#DIR)=#PB_DirectoryEntry_File
      If MatchRegularExpression(#REGEX,DirectoryEntryName(#DIR)) : Old_DB=DirectoryEntryName(#DIR) : EndIf
    EndIf
  Wend
  
  FinishDirectory(#DIR)
  
  hInternet=FTPInit()   
  
  If hInternet
    hConnect=FTPConnect(hInternet,FTP_Server,FTP_User,FTP_Pass,FTP_Port) 
    
    If hConnect
      
      SetGadgetText(#LOADING_TEXT,"Connected to FTP")
      
      FTPSetDir(hConnect,FTP_Folder)
      FTPSetDir(hConnect,FTP_SubFolder)
      FTPSetDir(hConnect,FTP_SubFolder2)
      
      FTPDir(hConnect,FTP_List())
      
      ForEach FTP_List()
        If MatchRegularExpression(#REGEX, FTP_List()) : New_DB=FTP_List() : EndIf
      Next
      
      FreeRegularExpression(#REGEX) 
      
      If Old_DB <> New_DB
        
        SetGadgetText(#LOADING_TEXT,"Downloading data file.")
        
        DeleteFile(Old_DB)
        
        FTPDownload(hConnect,New_DB,New_DB)
        FTPDownload(hConnect,"genres","genres")
        
        UM_Data_File=New_DB
        
      Else
        
        SetGadgetText(#LOADING_TEXT,"Data file up to date.")
        
        Delay(500)
        
        UM_Data_File=Old_DB
        
      EndIf
      
      FTPClose(hInternet)  
      
    Else
      
      MessageRequester("Error", "Cannot connect to FTP.",#PB_MessageRequester_Error|#PB_MessageRequester_Ok)
      
      UM_Data_File=Old_DB
      
    EndIf
    
  Else
    
    MessageRequester("Error", "Cannot connect to Network.",#PB_MessageRequester_Error|#PB_MessageRequester_Ok)
    
    UM_Data_File=Old_DB
    
  EndIf
  
  If Old_DB<>"" : UM_Data_File=Old_DB : EndIf
  
  If UM_Data_File="" : MessageRequester("Error","No database file found",#PB_MessageRequester_Error|#PB_MessageRequester_Ok) : EndIf
  
  FreeList(FTP_List())
  
EndProcedure

Procedure Load_DB()
  
  Protected CSV_File.i, Path.s
  Protected Count.i, I.i, Backslashes.i, Text_Line.s
  
  Protected NewList DB_List.s()
  
  path=Home_Path+UM_Data_File
  
  If path<>""
    
    ClearList(Comp_Database())
    ClearMap(Comp_Map())
    
    If ReadFile(CSV_File,Path,#PB_Ascii)
      
      Repeat
        AddElement(DB_List())
        DB_List()=ReadString(CSV_File)
      Until Eof(CSV_File)
      CloseFile(CSV_File)  

      ForEach DB_List()
        AddElement(Comp_Database())
        Text_Line=DB_List()
        Comp_Database()\C_Slave=LCase(StringField(Text_Line,1,Chr(59)))
        Comp_Database()\C_Folder=StringField(Text_Line,2,Chr(59))
        Comp_Database()\C_Genre=StringField(Text_Line,3,Chr(59))
        Comp_Database()\C_Name=StringField(Text_Line,4,Chr(59))
        Comp_Database()\C_Short=StringField(Text_Line,5,Chr(59))
        Comp_Database()\C_Icon=StringField(Text_Line,6,Chr(59))
        If Prefs_Type=1 : Comp_Map(LCase(Comp_Database()\C_Folder+"_"+Comp_Database()\C_Slave))=ListIndex(Comp_Database()) : EndIf
        If Prefs_Type=2 : Comp_Map(LCase(Comp_Database()\C_Folder+"_"+Comp_Database()\C_Icon))=ListIndex(Comp_Database()) : EndIf
      Next
      
    Else
      MessageRequester("Error","Cannot open database.",#PB_MessageRequester_Error|#PB_MessageRequester_Ok)
    EndIf
  EndIf  
  
  SortStructuredList(UM_Database(),#PB_Sort_Ascending|#PB_Sort_NoCase,OffsetOf(UM_Data\UM_Name),TypeOf(UM_Data\UM_Name))
  
  FreeList(DB_List())
  
EndProcedure

Procedure Draw_List()
  
  Protected Text.s, File.s
  Protected Count
  
  Pause_Window(#MAIN_WINDOW)
  
  ClearGadgetItems(#MAIN_LIST)
  
  ClearList(Filtered_List())
  
  If filter Or unknown
    Filter_List()
  Else
    DB_Filter(#False)
  EndIf

  ForEach Filtered_List()
    SelectElement(UM_Database(),Filtered_List())
    If UM_Database()\UM_Slave<>"" : File=UM_Database()\UM_Slave : EndIf
    If UM_Database()\UM_Icon<>"" : File=UM_Database()\UM_Icon : EndIf
    If Short_Names
      Text=UM_Database()\UM_Short+Chr(10)+File+Chr(10)+UM_Database()\UM_Path+Chr(10)+UM_Database()\UM_Genre
    Else
      Text=UM_Database()\UM_Name+Chr(10)+File+Chr(10)+UM_Database()\UM_Path+Chr(10)+UM_Database()\UM_Genre
    EndIf
    AddGadgetItem(#MAIN_LIST,-1,text)
    If ListIndex(UM_Database())>1
      If GetGadgetItemText(#MAIN_LIST, ListIndex(Filtered_List())-1,0)=UM_Database()\UM_Name
        SetGadgetItemColor(#MAIN_LIST, ListIndex(Filtered_List()), #PB_Gadget_FrontColor,#Red)
        SetGadgetItemColor(#MAIN_LIST, ListIndex(Filtered_List())-1, #PB_Gadget_FrontColor,#Red)
      EndIf
    EndIf 
    If UM_Database()\UM_Unknown=#True : SetGadgetItemColor(#MAIN_LIST, ListIndex(Filtered_List()), #PB_Gadget_FrontColor,#Blue) : EndIf
  Next
  
  For Count=0 To CountGadgetItems(#MAIN_LIST) Step 2
    SetGadgetItemColor(#MAIN_LIST,Count,#PB_Gadget_BackColor,$eeeeee)
  Next
  
  SetWindowTitle(#MAIN_WINDOW, "WHDLoadMenu Tool"+" "+Version+" (Showing "+Str(CountGadgetItems(#MAIN_LIST))+" of "+Str(ListSize(UM_Database()))+" Games)")
  
  SetGadgetState(#MAIN_LIST,0)
  SetActiveGadget(#MAIN_LIST)
  
  If ListSize(Filtered_List())<>0
    DisableGadget(#TAG_BUTTON,#False)
  Else
    DisableGadget(#TAG_BUTTON,#True)
  EndIf
    
  Resume_Window(#MAIN_WINDOW)
  
EndProcedure

Procedure Fix_List()
  
  Backup_Database(#False)
  
  Message_Window("Fixing Game List...")
  
  Protected File.s
  
  If ListSize(Comp_Database())=0  
    Get_Database()
    SetGadgetText(#LOADING_TEXT,"Loading database...")
    Load_DB()
  EndIf
  
  ForEach UM_Database()
    If Prefs_Type=1 : File=UM_Database()\UM_Slave : EndIf
    If Prefs_Type=2 : File=UM_Database()\UM_Icon : EndIf
    If FindMapElement(Comp_Map(),LCase(UM_Database()\UM_Folder+"_"+File))
      SelectElement(Comp_Database(),Comp_Map())
      UM_Database()\UM_Name=Comp_Database()\C_Name
      UM_Database()\UM_Short=Comp_Database()\C_Short
    EndIf
    If Not FindMapElement(Comp_Map(),LCase(UM_Database()\UM_Folder+"_"+File))
      UM_Database()\UM_Unknown=#True
    EndIf
  Next
  
  FreeMap(Comp_Map())
  ClearList(Comp_Database())
  
  SortStructuredList(UM_Database(),#PB_Sort_Ascending|#PB_Sort_NoCase,OffsetOf(UM_Data\UM_Name),TypeOf(UM_Data\UM_Name))
  
  DisableGadget(#SHORT_NAME_CHECK,#False)
  DisableGadget(#UNKNOWN_CHECK,#False)
  DisableGadget(#CASE_COMBO,#False)
  
  CloseWindow(#LOADING_WINDOW)
  
EndProcedure

Procedure Tag_List()
  
  Backup_Database(#False)
  
  Protected NewList Tags.i()
  Protected NewList Lines.i()
  
  Protected i, tag_entry.s
  
  For i=0 To CountGadgetItems(#MAIN_LIST)
    If GetGadgetItemState(#MAIN_LIST,i)=#PB_ListIcon_Selected
      SelectElement(Filtered_List(),i)
      SelectElement(UM_Database(),Filtered_List())
      AddElement(Tags())
      Tags()=ListIndex(UM_Database())
      AddElement(Lines())
      Lines()=i
    EndIf
  Next
  
  tag_entry=InputRequester("Add Tag", "Enter a new tag", "")
  
  If tag_entry<>""
    ForEach Tags()
      SelectElement(UM_Database(),Tags())
      UM_Database()\UM_Name=UM_Database()\UM_Name+" ("+tag_entry+")"
      SelectElement(Lines(),ListIndex(Tags()))
      SetGadgetItemText(#MAIN_LIST,Lines(),UM_Database()\UM_Name,0)
    Next
    ;Draw_List()
  EndIf
  
  FreeList(Tags())
  FreeList(Lines())
    
EndProcedure

Procedure Help_Window()
  
  Protected output$, output2$
  
  output$=""
  output$+"*** About ***"+Chr(10)
  output$+""+Chr(10)
  output$+"WHDLoadMenu Tool is a small utility that uses a small database to add better names to the WHDLoadMenu prefs files. WHDLoadMenu Tool is not perfect and "
  output$+"isn't clever enough to find some files and will still duplicate some entries, but it is still better than the default list. There is some basic editing "
  output$+"that can be done to the entries to help repair any errors."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Instructions ***"+Chr(10)
  output$+""+Chr(10)
  output$+"1. Copy the WHDLoadMenu.prefs file from your Amiga to your PC. Also... MAKE A BACKUP!"+Chr(10)
  output$+"2. Press the 'Load Prefs' button to open your WHDLoadMenu game list. Both slave and info based prefs files are supported and will be auto detected."+Chr(10)
  output$+"3. Press the 'Fix List' button to fix the game names. WHDLoadMenu tool does work best with slave based prefs files."+Chr(10)
  output$+"4. Make any other changes."+Chr(10)
  output$+"5. Press the 'Save Prefs' button to save the new prefs file. You can overwrite the old prefs file or save as a new file."+Chr(10)
  output$+"6. Copy the new prefs file back to the WHDLoadMenu drawer on your Amiga drive. The file must be called WHDLoadMenu.prefs for WHDLoadMenu to find it."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Games List ***"+Chr(10)
  output$+""+Chr(10)
  output$+"Duplicate entries are highlighted in red and unknown entries are highlighted in blue. Missing entries will only be highlighted after you have pressed the 'Fix List' button."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Editing ***"+Chr(10)
  output$+""+Chr(10)
  output$+"To edit a name, double click the entry on the list and change it's name in the new window."+Chr(10)
  output$+""+Chr(10)
  output$+"'Quick Tag' allows you can add multiple tags to the list entries. Just type the tag name into the new window and it will add it to the end of the game name."
  output$+" You can easily reduce any duplicate entries by using this button. Quick Tag will work with multiple selected entries. Use Ctrl or Shift when you click"
  output$+" the list to select multiple entries."+Chr(10)
  output$+""+Chr(10)
  output$+"'Undo' will reverse the last change that was made."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Database ***"+Chr(10)
  output$+""+Chr(10)
  output$+"'Use Short Names' replaces the game name with a 26 character short version."+Chr(10)
  output$+""+Chr(10)
  output$+"*** Filter ***"+Chr(10)
  output$+""+Chr(10)
  output$+"'Show Duplicates' filters the list and shows duplicate entries."+Chr(10)
  output$+""+Chr(10)
  output$+"'Show Unknown' filters the list and shows unknown entries. If an entry is marked as unknown, it may be worth checking to see it the slave has been updated."+Chr(10)
  output$+""+Chr(10)
  output$+"The case dropdown lets you set how the titles are generated for the new prefs file. The available options are 'Camel Case', 'lower case' and 'UPPER CASE'."+Chr(10)
  
  If OpenWindow(#HELP_WINDOW,0,0,400,450,"Help",#PB_Window_SystemMenu|#PB_Window_WindowCentered,WindowID(#MAIN_WINDOW))
    EditorGadget(#HELP_EDITOR,0,0,400,450,#PB_Editor_ReadOnly|#PB_Editor_WordWrap)
    DestroyCaret_()
  EndIf
  
  If IsGadget(#HELP_EDITOR)
    SetGadgetText(#HELP_EDITOR,output$)
  EndIf
  
  SetActiveWindow(#HELP_WINDOW)
  
EndProcedure 

Procedure Edit_Window()
  
  Backup_Database(#False)
  
  If OpenWindow(#EDIT_WINDOW,0,0,300,95,"Edit",#PB_Window_SystemMenu|#PB_Window_WindowCentered,WindowID(#MAIN_WINDOW))
    
    TextGadget(#PB_Any,5,8,50,24,"Name",#PB_Text_Center)
    StringGadget(#EDIT_NAME,55,5,240,24,UM_Database()\UM_Name)
    
    TextGadget(#PB_Any,5,38,50,24,"Short",#PB_Text_Center)
    StringGadget(#EDIT_SHORT,55,35,240,24,UM_Database()\UM_Short)
    If UM_Database()\UM_Short="" : DisableGadget(#EDIT_SHORT,#True) : EndIf
    
    If UM_Database()\UM_Slave<>""
      TextGadget(#PB_Any,5,68,50,24,"Slave",#PB_Text_Center)
      StringGadget(#EDIT_SLAVE,55,65,240,24,UM_Database()\UM_Slave)
    EndIf
    
    If UM_Database()\UM_Icon<>""
      TextGadget(#PB_Any,5,68,50,24,"Icon",#PB_Text_Center)
      StringGadget(#EDIT_ICON,55,65,240,24,UM_Database()\UM_Icon)
    EndIf
    
  EndIf
  
EndProcedure

Procedure Main_Window()

  If OpenWindow(#MAIN_WINDOW,0,0,900,600,"WHDloadMenu Tool "+Version,#PB_Window_SystemMenu|#PB_Window_ScreenCentered)
    
    Pause_Window(#MAIN_WINDOW)
    
    ListIconGadget(#MAIN_LIST,0,0,900,550,"Name",340,#PB_ListIcon_GridLines|#PB_ListIcon_FullRowSelect|#PB_ListIcon_MultiSelect)
    SetGadgetColor(#MAIN_LIST,#PB_Gadget_BackColor,#White)
    AddGadgetColumn(#MAIN_LIST,1,"Icon/Slave",200)
    AddGadgetColumn(#MAIN_LIST,2,"Path",340)

    ButtonGadget(#LOAD_BUTTON,5,555,80,40,"Load Prefs")
    ButtonGadget(#FIX_BUTTON,90,555,80,40,"Fix List")
    ButtonGadget(#SAVE_BUTTON,175,555,80,40,"Save Prefs")
    ButtonGadget(#TAG_BUTTON,260,555,80,40,"Quick Tag")
    ButtonGadget(#CLEAR_BUTTON,345,555,80,40,"Clear List")
    ButtonGadget(#UNDO_BUTTON,430,555,80,40,"Undo")
    ButtonGadget(#HELP_BUTTON,815,555,80,40,"Help")
    
    CheckBoxGadget(#SHORT_NAME_CHECK,535,553,120,22,"Use Short Names")
    CheckBoxGadget(#DUPE_CHECK,660,553,105,22,"Show Duplicates")
    CheckBoxGadget(#UNKNOWN_CHECK,535,573,105,22,"Show Unknown")
    
    ComboBoxGadget(#CASE_COMBO,660,575,105,20)
    AddGadgetItem(#CASE_COMBO,-1,"Camel Case")
    AddGadgetItem(#CASE_COMBO,-1,"lower Case")
    AddGadgetItem(#CASE_COMBO,-1,"UPPER CASE")
    
    SetGadgetState(#CASE_COMBO,Output_Case)
    SetGadgetState(#SHORT_NAME_CHECK,Short_Names)
    SetGadgetState(#DUPE_CHECK,Filter)
    
    DisableGadget(#FIX_BUTTON,#True)
    DisableGadget(#SAVE_BUTTON,#True)

    DisableGadget(#SHORT_NAME_CHECK,#True)
    DisableGadget(#CLEAR_BUTTON,#True)
    DisableGadget(#UNKNOWN_CHECK,#True)
    DisableGadget(#DUPE_CHECK,#True)
    DisableGadget(#TAG_BUTTON,#True)
    DisableGadget(#UNDO_BUTTON,#True)
    DisableGadget(#CASE_COMBO,#True)
    
    Resume_Window(#MAIN_WINDOW)
    
  EndIf
  
EndProcedure

;- ### Init Program ###

Main_Window()

;- ### Main Loop ###

Repeat
  
  event=WaitWindowEvent()
  gadget=EventGadget()
  
  Select event
      
    Case #PB_Event_CloseWindow
      If EventWindow()=#HELP_WINDOW
        CloseWindow(#HELP_WINDOW)
      EndIf
      If EventWindow()=#EDIT_WINDOW
        CloseWindow(#EDIT_WINDOW)
        Define Text.s
        Define info_type.s
        
        If UM_Database()\UM_Slave<>"" : info_type=UM_Database()\UM_Slave : EndIf
        If UM_Database()\UM_Icon<>"" : info_type=UM_Database()\UM_Icon : EndIf
        
        If Short_Names
          Text=UM_Database()\UM_Short+Chr(10)+info_type+Chr(10)+UM_Database()\UM_Path
        Else
          Text=UM_Database()\UM_Name+Chr(10)+info_type+Chr(10)+UM_Database()\UM_Path
        EndIf
        SetGadgetItemText(#MAIN_LIST,GetGadgetState(#MAIN_LIST),Text)
      EndIf
      If EventWindow()=#MAIN_WINDOW
        If MessageRequester("Exit WHDLoad Tool", "Do you want to quit?",#PB_MessageRequester_YesNo|#PB_MessageRequester_Warning)=#PB_MessageRequester_Yes
          close=#True
        EndIf  
      EndIf
            
      Case #PB_Event_Gadget
      
      Select gadget
          
        Case #LOAD_BUTTON
          If ListSize(UM_Database())>0
            ClearList(UM_Database())
            Pause_Window(#MAIN_WINDOW)
            ClearGadgetItems(#MAIN_LIST)
            Resume_Window(#MAIN_WINDOW)
          EndIf
          SetWindowTitle(#MAIN_WINDOW,"WHDLoadMenu Tool "+Version)
          Load_CSV()
          Draw_List()
          
        Case #SAVE_BUTTON
          Save_CSV()
          
        Case #UNDO_BUTTON
          If MessageRequester("Warning","Undo Last Change?",#PB_MessageRequester_Warning|#PB_MessageRequester_YesNo)=#PB_MessageRequester_Yes
            ClearList(UM_Database())
            CopyList(Undo_Database(),UM_Database())
            DisableGadget(#UNDO_BUTTON,#True)
            Draw_List()
          EndIf
          
        Case #FIX_BUTTON
          Fix_List()
          Draw_List()
          
        Case #TAG_BUTTON
          Tag_List()
                    
        Case #CLEAR_BUTTON
          If MessageRequester("Warning","Clear All Data?",#PB_MessageRequester_YesNo|#PB_MessageRequester_Warning)=#PB_MessageRequester_Yes
          FreeList(Undo_Database())
          FreeList(UM_Database())
          FreeList(Filtered_List())
          Pause_Window(#MAIN_WINDOW)
          ClearGadgetItems(#MAIN_LIST)
          DisableGadget(#FIX_BUTTON,#True)
          DisableGadget(#SAVE_BUTTON,#True)
          DisableGadget(#DUPE_CHECK,#True)
          DisableGadget(#SHORT_NAME_CHECK,#True)
          DisableGadget(#CLEAR_BUTTON,#True)
          DisableGadget(#TAG_BUTTON,#True)
          DisableGadget(#UNKNOWN_CHECK,#True)
          DisableGadget(#UNDO_BUTTON,#True)
          DisableGadget(#CASE_COMBO,#True)
          Unknown=#False
          Filter=#False
          Short_Names=#False
          SetGadgetState(#DUPE_CHECK,Filter)
          SetGadgetState(#UNKNOWN_CHECK,Unknown)
          SetGadgetState(#SHORT_NAME_CHECK,Short_Names)
          SetWindowTitle(#MAIN_WINDOW,"WHDLoadMenu Tool "+Version)
          Global NewList UM_Database.UM_Data()
          Global NewList Undo_Database.UM_Data()
          Global NewList Filtered_List.i()
          Resume_Window(#MAIN_WINDOW)
          EndIf
          
        Case #HELP_BUTTON
          Help_Window()
          
        Case #SHORT_NAME_CHECK
          Short_Names=GetGadgetState(#SHORT_NAME_CHECK)
          If ListSize(UM_Database())>0
            Draw_List()
          EndIf
          
        Case #CASE_COMBO
          If EventType()=#PB_EventType_Change
            Output_Case=GetGadgetState(#CASE_COMBO)
          EndIf
          
        Case #EDIT_NAME
          If EventType()=#PB_EventType_Change
            UM_Database()\UM_Name=GetGadgetText(#EDIT_NAME)
          EndIf
          
        Case #EDIT_SLAVE
          If EventType()=#PB_EventType_Change
            UM_Database()\UM_Slave=GetGadgetText(#EDIT_SLAVE)
          EndIf
          
        Case #EDIT_ICON
          If EventType()=#PB_EventType_Change
            UM_Database()\UM_Icon=GetGadgetText(#EDIT_ICON)
          EndIf
          
        Case #EDIT_SHORT
          If EventType()=#PB_EventType_Change
            UM_Database()\UM_Short=GetGadgetText(#EDIT_SHORT)
          EndIf
          
        Case #DUPE_CHECK
          Filter=GetGadgetState(#DUPE_CHECK)
          Draw_List()
          
        Case #UNKNOWN_CHECK
          Unknown=GetGadgetState(#UNKNOWN_CHECK)
          Draw_List()
          
        Case #MAIN_LIST
          If EventType()=#PB_EventType_LeftDoubleClick
            If ListSize(Filtered_List())>0
              SelectElement(Filtered_List(),GetGadgetState(#MAIN_LIST))
              SelectElement(UM_Database(),Filtered_List())
              Edit_Window()
            EndIf
            
          EndIf
          
      EndSelect
             
      
  EndSelect
  
Until close=#True

End
; IDE Options = PureBasic 6.00 Beta 3 (Windows - x64)
; CursorPosition = 582
; FirstLine = 403
; Folding = AB2A-
; Optimizer
; EnableThread
; EnableXP
; DPIAware
; UseIcon = boing.ico
; Executable = WHDLoadMenu_Tool_32.exe
; Compiler = PureBasic 6.00 Beta 1 - C Backend (Windows - x64)
; Debugger = Standalone
; IncludeVersionInfo
; VersionField0 = 0,0,0,2
; VersionField1 = 0,0,0,2
; VersionField2 = MrV2K
; VersionField3 = IGame Tool
; VersionField4 = 0.2 Alpha
; VersionField5 = 0.2 Alpha
; VersionField6 = IGame Conversion Tool
; VersionField7 = IG_Tool
; VersionField8 = IGame_Tool.exe
; VersionField9 = 2021 Paul Vince
; VersionField15 = VOS_NT
; VersionField16 = VFT_APP
; VersionField17 = 0809 English (United Kingdom)