format PE GUI 4.0
entry start

include 'win32ax.inc'


IDR_MENU = 40
IDR_ICON = 414
IDM_OPEN = 201
IDM_ABOUT = 202
IDM_EXIT = 203
ID_DIALOG = 456
ID_TREE_VIEW = 1255
WC_TREEVIEW   equ          "SysTreeView"
UM_CHECKSTATECHANGE = WM_USER + 100
STANDARD_RIGHTS_READ = 00020000h
TOKEN_QUERY = 0008h
TOKEN_READ =  STANDARD_RIGHTS_READ+TOKEN_QUERY
TokenUser = 1
ERROR_INSUFFICIENT_BUFFER = 122
BUF_SZ = 260
VIEW_BTN = 108
DELETE_BTN = 109
INFINITE = 4294967295

struct TVHITTESTINFO
        pt      POINT
        flags   dd      ?       ;UINT
        hItem   dd      ?       ;HTREEITEM
ends

struct SID_AND_ATTRIBUTES
      Sid dd ?
      Attributes dd ?
ends

struct TOKEN_USER
      User SID_AND_ATTRIBUTES
ends

struct RecycleMetaOld
      Header db 8 dup(?)
      FileSz db 8 dup(?)
      DeleteTs db 8 dup(?)
      FileName db 520 dup(?)
ends

struct RecycleMetaNew
       Header db 8 dup(?)
       FileSz db 8 dup(?)
       DeleteTs db 8 dup(?)
       FileNameLen db 4 dup(?)
       FileName db ?
ends


section '.text' code readable executable
start:
     invoke InitCommonControls
     call CreateWindow
     invoke ExitProcess,0


proc CreateWindow
    invoke GetModuleHandle,0
    mov [wc.hInstance], eax
    mov eax, sizeof.WNDCLASSEX
    mov [wc.cbSize],eax
    mov [wc.lpfnWndProc],WinProc
    mov [wc.style],CS_HREDRAW+CS_VREDRAW
    invoke LoadIcon,[wc.hInstance],IDR_ICON
    mov [wc.hIcon],eax
    mov [wc.hIconSm],eax
    invoke LoadCursor,NULL,IDC_ARROW
    mov [wc.hCursor],eax
    mov [wc.hbrBackground],COLOR_WINDOW+1
    mov [wc.lpszClassName],_class
    mov [wc.cbClsExtra], 0
    mov [wc.cbWndExtra], 0
    mov [wc.lpszMenuName], 0
    invoke RegisterClassEx,wc
    test eax,eax
    jz exit

    invoke LoadMenu,[wc.hInstance],IDR_MENU
    invoke CreateWindowEx,0,_class,_title,WS_OVERLAPPEDWINDOW+WS_CLIPCHILDREN,\
                          500,300,800,400,\
                          NULL,eax,[wc.hInstance],NULL

    test eax,eax
    jz exit
    mov [hWnd], eax

    push eax
    call AddTreeView
    push [hWnd]
    call AddButtons
    push [hWnd]
    call AddEdit
    push [hWnd]
    call AddLabels

    invoke EnumChildWindows,[hWnd],EnumChildProc,0

    invoke ShowWindow,[hWnd],SW_SHOWNORMAL
    invoke UpdateWindow,[hWnd]
 loopm:
    invoke GetMessage,msg,NULL,0,0
    cmp eax,1
    jb exit
    invoke TranslateMessage,msg
    invoke DispatchMessage,msg
    jmp loopm
 exit:
    ret
endp

proc EnumChildProc hwnd, lparam
    invoke SendMessage,[hwnd],WM_SETFONT,[hf],[lparam]
    mov eax,1
    mov esp,ebp
    pop ebp
    ret 8
endp

proc AddButtons hwnd
     push edi
     mov edi, [hwnd]
     invoke CreateWindowEx,0,'BUTTON','View',\
     WS_VISIBLE+WS_CHILD,\
     0,5,60,40,edi,\
     VIEW_BTN, [wc.hInstance],0
     mov [View_Hwnd], eax


     invoke CreateWindowEx,0,'BUTTON','Delete',\
     WS_VISIBLE+WS_CHILD,\
     80,5,60,40,edi,\
     DELETE_BTN, [wc.hInstance],0
     mov [Delete_Hwnd], eax

     .exit:
        pop edi
        mov esp,ebp
        pop ebp
        ret 0x4
endp

proc AddEdit hwnd
     push edi
     mov edi, [hwnd]
     invoke CreateWindowEx,WS_EX_CLIENTEDGE,'EDIT',0,\
     WS_VISIBLE+WS_CHILD+ES_MULTILINE+ES_READONLY+ES_AUTOVSCROLL+WS_VSCROLL+WS_HSCROLL,\
     220,40,550,200,edi,\
     0, [wc.hInstance],0
     mov [Edit_Hwnd], eax
     invoke SendMessage,[Edit_Hwnd],EM_LIMITTEXT,0,64000

     invoke EnumChildWindows,[hWnd],EnumChildProc,0

     .exit:
        pop edi
        mov esp,ebp
        pop ebp
        ret 0x4
endp

proc AddLabels hwnd
     push edi
     mov edi, [hwnd]
     invoke CreateWindowEx,0,'STATIC','',\
     WS_VISIBLE+WS_CHILD,\
     220,250,150,40,edi,\
     0, [wc.hInstance],0
     mov [Cnt_Hwnd], eax

     .exit:
        pop edi
        mov esp,ebp
        pop ebp
        ret 0x4
endp


proc strlen str1
    push esi
    push edx
    xor esi,esi
    mov edx, [str1]
   .L1:
    mov dl, byte [edx+esi]
    cmp dl,0
    jz .exit
    inc esi
    jmp .L1

  .exit:
    mov eax,esi
    pop edx
    pop esi
    mov esp,ebp
    pop ebp
    ret 0x4
endp

proc GetRecyclePath uses edx
    locals
        hToken dd 0
        hProcess dd 0
        ptu dd 0
        dwSize dd 0
        StrSid dd 0
        _Recycle_C db "C:\$RECYCLE.BIN\",0
    endl
    invoke GetCurrentProcess
    mov [hProcess], eax
    invoke OpenProcessToken,[hProcess],TOKEN_READ,addr hToken
    cmp eax,0
    jz .exit

    invoke GetTokenInformation,[hToken],TokenUser,NULL,0,addr dwSize
    cmp eax,0
    jnz .exit
    invoke GetLastError
    cmp eax, ERROR_INSUFFICIENT_BUFFER
    jnz .exit
    invoke GetProcessHeap
    invoke HeapAlloc,eax,0,[dwSize]
    cmp eax,0
    jz .exit
    mov [ptu],eax
    invoke GetTokenInformation,[hToken],TokenUser,[ptu],[dwSize],addr dwSize
    jz .cleanup
    mov ecx,dword [ptu]
    mov edx,dword [ecx]
    lea eax,[StrSid]
    invoke ConvertSidToStringSid,edx,eax
    cmp eax,0
    jz .cleanup

    push BUF_SZ
    lea eax,[_Recycle_C]
    push eax
    push _Recycle_path
    call StrCpy

    push BUF_SZ
    push [StrSid]
    push _Recycle_path
    call StrCat

    invoke LocalFree,[StrSid]
    invoke GetProcessHeap
    invoke HeapFree,eax,0,[ptu]
    jmp .exit


   .cleanup:
        invoke GetProcessHeap
        invoke HeapFree,eax,0,[ptu]
   .exit:
        ret
endp

proc StrCpy buffer, src, size
     push ecx
     push esi
     push edx

     xor ecx,ecx
     mov esi, [src]
     mov edx, [buffer]

    .L1:
     mov al, byte [esi+ecx]
     mov byte [edx+ecx],al
     cmp al,0
     jz .exit
     inc ecx
     cmp ecx,[size]
     jz .exit
     jmp .L1

    .exit:
     pop edx
     pop esi
     pop ecx
     mov esp,ebp
     pop ebp
     ret 12
endp

proc StrCat buffer, src, size
     push edx
     push esi
     push ecx
     push ebx

     xor ebx,ebx
     xor ecx,ecx
     mov edx,[buffer]
     mov esi,[src]
    .L1:
      mov al,byte [edx+ebx]
      cmp al,0
      jz .null_found
      inc ebx
      jmp .L1

    .null_found:
      cmp ebx,[size]
      jae .exit
      mov al,[esi+ecx]
      cmp al,0
      jz .move_null
      mov byte [edx+ebx],al
      inc ecx
      inc ebx
      jmp .null_found

    .move_null:
      mov byte [edx+ebx],0

    .exit:
      pop ebx
      pop ecx
      pop esi
      pop edx
      mov esp,ebp
      pop ebp
      ret 12
endp

proc AddTreeView hwnd
     locals
        rc RECT ?
     endl
     push edi
     mov edi, [hwnd]
     invoke GetClientRect,[hWnd],addr rc
     invoke CreateWindowEx,WS_EX_CLIENTEDGE,TreeViewStr,0,\
     WS_VISIBLE+WS_CHILD+TVS_CHECKBOXES+TVS_HASBUTTONS+TVS_LINESATROOT,\
     0,50,200,[rc.bottom],edi,\
     ID_TREE_VIEW, [wc.hInstance], 0
     mov [TreeView],eax

     mov [tvinsert.hParent],NULL
     mov [tvinsert.hInsertAfter],TVI_ROOT
     mov [tvinsert.item.mask],TVIF_TEXT
     mov [tvinsert.item.pszText],_System
     invoke SendMessage,[TreeView],TVM_INSERTITEM,0,tvinsert
     mov [Root],eax

     mov [tvinsert.hParent],eax
     mov [tvinsert.hInsertAfter],TVI_LAST
     mov [tvinsert.item.pszText],_Recycle
     invoke  SendMessage,[TreeView],TVM_INSERTITEM,0,tvinsert

     mov eax,[Root]
     mov [tvinsert.hParent], eax
     mov [tvinsert.item.pszText],_Temp
     mov [tvinsert.item.mask],TVIF_TEXT
     invoke SendMessage,[TreeView],TVM_INSERTITEM,0,tvinsert

     mov eax, [Root]
     invoke SendMessage,[TreeView],TVM_EXPAND,TVE_EXPAND,eax

     mov [tvinsert.hParent],NULL
     mov [tvinsert.hInsertAfter],TVI_ROOT
     mov [tvinsert.item.mask],TVIF_TEXT
     mov [tvinsert.item.pszText],_Internet
     invoke SendMessage,[TreeView],TVM_INSERTITEM,0,tvinsert
     mov [Second],eax

     mov [tvinsert.hParent],eax
     mov [tvinsert.hInsertAfter],TVI_LAST
     mov [tvinsert.item.pszText],_Cookie
     invoke SendMessage,[TreeView],TVM_INSERTITEM,0,tvinsert

     mov [tvinsert.item.pszText],_History
     invoke  SendMessage,[TreeView],TVM_INSERTITEM,0,tvinsert

     mov eax, [Second]
     invoke SendMessage,[TreeView],TVM_EXPAND,TVE_EXPAND,eax


     pop edi
     mov esp, ebp
     pop ebp
     ret 0x4
endp

proc ErrorMsg
locals
    buf dd 0
endl
     mov esi,1024
     invoke FormatMessage,FORMAT_MESSAGE_ALLOCATE_BUFFER+\
     FORMAT_MESSAGE_FROM_SYSTEM+FORMAT_MESSAGE_IGNORE_INSERTS,\
     NULL,eax,0,addr buf,0,NULL
     invoke MessageBox,NULL,[buf],[buf], MB_OK
     invoke LocalFree,[buf]


     ret
endp

proc ExpandStrs
     locals
          LocalSet db "%USERPROFILE%\Local Settings\Temp",0
          Tmp db "%temp%",0
          WTmp db "%windir%\temp",0
          Cookie_1 db "%LOCALAPPDATA%\Microsoft\Internet Explorer\DOMStore",0
          Cookie_2 db "%USERPROFILE%\AppData\LocalLow\Microsoft\Internet Explorer\DOMStore",0
          ;HKCU\Software\Microsoft\Internet Explorer\IntelliForms\Storage1
          ;HKCU\Software\Microsoft\Internet Explorer\IntelliForms\Storage2
          history_1 db "%LocalAppData%\Microsoft\Internet Explorer\Recovery\Active",0
          history_2 db "%LocalAppData%\Microsoft\Internet Explorer\Recovery\Immersive\Active",0
          history_3 db "%LocalAppData%\Microsoft\Internet Explorer\Recovery\Last Active",0

     endl
      invoke ExpandEnvironmentStrings,addr LocalSet,LocalSettings,BUF_SZ
      invoke ExpandEnvironmentStrings,addr Tmp,Temp,BUF_SZ
      invoke ExpandEnvironmentStrings,addr WTmp,WinTmp,BUF_SZ
      invoke ExpandEnvironmentStrings,addr Cookie_1,IE_Cookies,BUF_SZ
      invoke ExpandEnvironmentStrings,addr Cookie_2,IE_Cookies2,BUF_SZ
      invoke ExpandEnvironmentStrings,addr history_1,IE_History1,BUF_SZ
      invoke ExpandEnvironmentStrings,addr history_2,IE_History2,BUF_SZ
      invoke ExpandEnvironmentStrings,addr history_3,IE_History3,BUF_SZ
     ret
endp

proc WinProc uses ebx esi edi,hwnd,wmsg,wparam,lparam
     cmp [wmsg],WM_DESTROY
     je .DESTROY
     cmp [wmsg],WM_COMMAND
     je .WMCOMMAND
     cmp [wmsg],WM_NOTIFY
     je .WMNOTIFY
     cmp [wmsg],UM_CHECKSTATECHANGE
     je .UM_CHECKSTATECHANGE
     cmp [wmsg],WM_CREATE
     je .WM_INIT
     cmp [wmsg],WM_CTLCOLORSTATIC
     je .STATIC
 .DEFAULT:
     invoke DefWindowProc,[hwnd],[wmsg],[wparam],[lparam]
     jmp .END
 .WM_INIT:
     invoke CreateFont,15,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,ANSI_CHARSET,OUT_DEFAULT_PRECIS,\
     CLIP_DEFAULT_PRECIS,DEFAULT_QUALITY,DEFAULT_PITCH+FF_ROMAN,'Tahoma'
     mov [hf],eax
     call GetRecyclePath
     call ExpandStrs
     jmp .DEFAULT
 .WMNOTIFY:
     mov eax,[lparam]
     mov ebx,[eax+NMHDR.idFrom]
     cmp ebx,ID_TREE_VIEW
     jnz .DEFAULT
     mov edi,[eax+NMHDR.code]
     cmp edi,NM_CLICK
     jnz .DEFAULT
     invoke GetMessagePos
     mov edi, eax
     and edi, 0FFFFh
     mov [hit.pt.x], edi
     mov esi, eax
     shr esi, 16
     mov [hit.pt.y], esi
     mov esi, [lparam]
     invoke MapWindowPoints,HWND_DESKTOP,[esi+NMHDR.hwndFrom],hit.pt,1
     test eax,eax
     jz .END
     invoke SendMessage,[esi+NMHDR.hwndFrom],TVM_HITTEST,0,hit
     test eax,eax
     jz .DEFAULT

     mov eax,TVHT_ONITEMSTATEICON
     and eax,[hit.flags]
     jz .END
     invoke PostMessage,[hwnd],UM_CHECKSTATECHANGE,0,[hit.hItem]
     test eax, eax
     jz .END
     jmp .DEFAULT
 .STATIC:
     invoke CreateSolidBrush,0x00ffffff
     jmp .END
 .UM_CHECKSTATECHANGE:
     locals
        it TV_ITEM 0
        hand dd 0
     endl
     mov eax, TVIF_HANDLE
     or eax, TVIF_STATE
     or eax, TVIF_CHILDREN
     mov [it.mask], eax
     mov eax,[lparam]
     mov [it.hItem],eax
     invoke SendMessage,[TreeView],TVM_SELECTITEM,TVGN_CARET,[it.hItem]
     mov [it.stateMask],TVIS_STATEIMAGEMASK
     invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
     test eax,eax
     jz .END
     mov eax, [it.cChildren]
     cmp eax,0
     jz .child
     cmp eax,1
     jnz .END
     mov eax,[it.state]
     and eax, 0FF00h
     cmp eax,2000h
     jz .check_loop
     cmp eax,1000h
     jz .uncheck_loop

     .uncheck_loop:
        invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_CHILD,[it.hItem]
        test eax,eax
        jz .END
        mov [it.hItem],eax
     .L1:
        invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
        test eax,eax
        jz .END
        mov eax,[it.state]
        cmp eax,1000h
        jz .continue_1
        cmp eax,2000h
        jnz .END
        mov [it.state],1000h
        invoke SendMessage,[TreeView],TVM_SETITEM,0,addr it
        test eax,eax
        jz .END
        jmp .continue_1

      .continue_1:
        invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_NEXT,[it.hItem]
        mov [it.hItem],eax
        jmp .L1


     .check_loop:
        invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_CHILD,[it.hItem]
        test eax,eax
        jz .END
        mov [it.hItem],eax
     .L2:
        invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
        test eax,eax
        jz .END
        mov eax,[it.state]
        cmp eax,2000h
        jz .continue_2
        cmp eax,1000h
        jnz .END
        mov [it.state],2000h
        invoke SendMessage,[TreeView],TVM_SETITEM,0,addr it
        test eax,eax
        jz .END
        jmp .continue_2

      .continue_2:
        invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_NEXT,[it.hItem]
        mov [it.hItem],eax
        jmp .L2

     .child:
        invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_PARENT,[it.hItem]
        test eax,eax
        jz .END
        mov esi,[it.state]
        cmp esi, 1000h
        jnz .END
        mov [it.hItem],eax
        invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
        test eax,eax
        jz .END
        mov eax,[it.state]
        mov esi,eax
        and esi,00FFh
        and eax,0FF00h
        cmp eax,2000h
        jnz .END
        or esi,1000h
        mov [it.state],esi
        invoke SendMessage,[TreeView],TVM_SETITEM,0,addr it
        test eax,eax
        jz .END
        jmp .END
 .WMCOMMAND:
     mov eax,[wparam]
     and eax,0FFFFh
     cmp eax,IDM_ABOUT
     je .ABOUT
     cmp eax,IDM_EXIT
     je .DESTROY
     cmp eax,VIEW_BTN
     je .VIEW
     cmp eax,DELETE_BTN
     je .DELETE
     jmp .DEFAULT
      .ABOUT:
        invoke DialogBoxParam,[wc.hInstance],37,[hWnd],DlgProc,NULL
        jmp .END
 .VIEW:
     mov [File_Cnt], 0
     invoke SetWindowText,[Edit_Hwnd],''
     invoke CreateThread,0,0,SystemSelection,0,0,0
     mov [hThread_System],eax
     invoke CreateThread,0,0,InternerExplorerProc,0,0,0
     mov [hThread_System+4],eax
     invoke CreateThread,0,0,WaitUpdateCount,0,0,0
     invoke CloseHandle,eax
     jmp .END
 .DELETE:
     mov eax, [File_Cnt]
     cmp eax,0
     jz .END
     invoke MessageBox,NULL,"Are you sure you want to remove these files?","Delete",MB_OKCANCEL
     cmp eax,IDCANCEL
     jz .END
     invoke CreateThread,0,0,RemoveFiles,0,0,0
     mov [hThread_System+8],eax
     invoke CreateThread,0,0,WaitUpdateCount,1,0,0
     invoke CloseHandle,eax
     jmp .END
 .DESTROY:
     invoke PostQuitMessage,0
 .END:
     ret
endp


proc RemoveFiles
     locals
        it TV_ITEM 0
        buf db 260 dup(?)
     endl
     mov eax, TVIF_HANDLE
     or eax, TVIF_STATE
     or eax, TVIF_TEXT
     mov [it.mask], eax
     mov [it.stateMask],TVIS_STATEIMAGEMASK
     mov [it.cchTextMax],260
     lea eax,[buf]
     mov [it.pszText], eax
     invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_CHILD,[Root]
     test eax,eax
     jz .exit
     mov [it.hItem],eax
     invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
     test eax,eax
     jz .exit

    .L1:
     mov eax,[it.state]
     and eax,0FF00h
     cmp eax,1000h
     je .L2
     cmp eax,2000h
     jne .exit
     push _Recycle_path
     call DeleteFiles
     .L2:
      invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_NEXT,[it.hItem]
      mov [it.hItem],eax
      invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
      mov eax,[it.state]
      and eax, 0FF00h
      cmp eax,1000h
      jz .second
      cmp eax,2000h
      jne .cookies

      push LocalSettings
      call DeleteFiles

      push Temp
      call DeleteFiles

      push WinTmp
      call DeleteFiles

    .second:

     invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_CHILD,[Second]
     test eax,eax
     jz .exit
     mov [it.hItem],eax
     invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
     test eax,eax
     jz .exit

     .cookies:
     mov eax,[it.state]
     and eax,0FF00h
     cmp eax,2000h
     jne .history
      push IE_Cookies
      call DeleteFiles

      push IE_Cookies2
      call DeleteFiles

     .history:
      invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_NEXT,[it.hItem]
      mov [it.hItem],eax
      invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
      mov eax, [it.state]
      and eax, 0FF00h
      cmp eax,2000h
      jne .exit
      ;search history calls
      ;

      push IE_History1
      call DeleteFiles

      push IE_History2
      call DeleteFiles

      push IE_History3
      call DeleteFiles

    .exit:
     ret
endp

proc DeleteFiles, path
   ; invoke MessageBox,NULL,[path],_title,MB_OK

     locals
      data WIN32_FIND_DATA ?
      hand dd ?
      tmp db "\*",0
      back_slash db "\",0
      root_dir db "..",0
      curr_dir db ".",0
      space_char db "   ",0
      tmpbuf db 260 dup(?)
     endl
     push edx
     push ebx
     push ecx
     xor ecx,ecx

     push 260
     push [path]
     lea edx,[tmpbuf]
     push edx
     call StrCpy

     push 260
     lea edx,[tmp]
     push edx
     lea edx,[tmpbuf]
     push edx
     call StrCat

     invoke FindFirstFile,addr tmpbuf,addr data
     cmp eax,INVALID_HANDLE_VALUE
     jz .exit
     mov [hand],eax
     mov eax, [data.dwFileAttributes]
     and eax, FILE_ATTRIBUTE_DIRECTORY
     jz .file
     jnz .directory
    .next:

     invoke FindNextFile,[hand],addr data
     test eax,eax
     jz .exit
     mov eax, [data.dwFileAttributes]
     and eax, FILE_ATTRIBUTE_DIRECTORY
     jz .file
     jnz .directory
    .directory:
      lea edx, [data.cFileName]
      push edx
      lea edx, [curr_dir]
      push edx
      call strcmp
      cmp eax,0
      jz .next

      lea edx, [data.cFileName]
      push edx
      lea edx, [curr_dir]
      push edx
      call strcmp
      cmp eax,0
      jz .next

      push 260
      push [path]
      lea eax,[tmpbuf]
      push eax
      call StrCpy

      push 260
      lea edx,[back_slash]
      push edx
      lea edx,[tmpbuf]
      push edx
      call StrCat

      push 260
      lea edx, [data.cFileName]
      push edx
      lea edx,[tmpbuf]
      push edx
      call StrCat

      lea edx,[tmpbuf]
      push edx
      call DeleteFiles

      jmp .next
    .file:
       push 260
       push [path]
       lea eax,[tmpbuf]
       push eax
       call StrCpy

       push 260
       lea edx,[back_slash]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat

       push 260
       lea edx, [data.cFileName]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat

       invoke DeleteFile,addr tmpbuf
       jmp .next

   .exit:
    invoke FindClose,[hand]
    mov esp,ebp
    pop ebp
    ret 4
endp

proc DlgProc uses esi edi ebx,hwnddlg,msg,wparam,lparam
  cmp [msg],WM_INITDIALOG
  je .wminit
  cmp [msg],WM_COMMAND
  je .wmcommand
  cmp [msg],WM_CLOSE
  je .wmclose
  xor eax,eax
  jmp .final

  .wminit:
    invoke GetSystemMetrics,SM_CXSMICON
    mov esi,eax
    invoke GetSystemMetrics,SM_CYSMICON
    mov edi,eax
    invoke LoadImage,[wc.hInstance],IDR_ICON,IMAGE_ICON,esi,edi,0
    test eax,eax
    jz .final
    mov [hIcon],eax
    invoke SendMessage,[hwnddlg],WM_SETICON,ICON_SMALL,[hIcon]
    jmp .final

  .wmcommand:
    jmp .wmclose

  .wmclose:
    invoke EndDialog,[hwnddlg],0

  .final:
    ret
endp

proc WaitUpdateCount, p
     mov eax,[p]
     cmp eax, 1
     jz .second
     invoke WaitForMultipleObjects,2,hThread_System,1,INFINITE
     invoke CloseHandle,[hThread_System]
     invoke CloseHandle,[hThread_System+4]

     push [File_Cnt]
     call DisplayCnt
     jmp .exit

   .second:
     invoke WaitForSingleObject,[hThread_System+8],INFINITE
     invoke MessageBox,NULL,"Completed","INFO",MB_OK

   .exit:

     mov esp,ebp
     pop ebp
     ret 4
endp

proc SystemSelection
     locals
        it TV_ITEM 0
        buf db 260 dup(?)
     endl
     mov eax, TVIF_HANDLE
     or eax, TVIF_STATE
     or eax, TVIF_TEXT
     mov [it.mask], eax
     mov [it.stateMask],TVIS_STATEIMAGEMASK
     mov [it.cchTextMax],260
     lea eax,[buf]
     mov [it.pszText], eax
     invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_CHILD,[Root]
     test eax,eax
     jz .exit
     mov [it.hItem],eax
     invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
     test eax,eax
     jz .exit

    .L1:
     mov eax,[it.state]
     and eax,0FF00h
     cmp eax,1000h
     je .L2
     cmp eax,2000h
     jne .exit
     push _Recycle_path
     call ListFilesRecycle
     .L2:
      invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_NEXT,[it.hItem]
      mov [it.hItem],eax
      invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
      mov eax,[it.state]
      and eax, 0FF00h
      cmp eax,1000h
      jz .exit
      cmp eax,2000h
      jne .exit

      push LocalSettings
      call ListFiles

      push Temp
      call ListFiles

      push WinTmp
      call ListFiles

    .exit:
     ret
endp

proc InternerExplorerProc
     locals
         it TV_ITEM 0
         PathBuffer db 260 dup(?)
         ;%USERPROFILE%\Cookies\
         ;%APPDATA%\Microsoft\Windows\Cookies\
     endl

     mov eax, TVIF_HANDLE
     or eax, TVIF_STATE
     mov [it.mask], eax
     mov [it.stateMask],TVIS_STATEIMAGEMASK
     invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_CHILD,[Second]
     test eax,eax
     jz .exit
     mov [it.hItem],eax
     invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
     test eax,eax
     jz .exit

     .cookies:
     mov eax,[it.state]
     and eax,0FF00h
     cmp eax,2000h
     jne .history
      push IE_Cookies
      call ListFiles

      push IE_Cookies2
      call ListFiles

     .history:
      invoke SendMessage,[TreeView],TVM_GETNEXTITEM,TVGN_NEXT,[it.hItem]
      mov [it.hItem],eax
      invoke SendMessage,[TreeView],TVM_GETITEM,0,addr it
      mov eax, [it.state]
      and eax, 0FF00h
      cmp eax,2000h
      jne .exit
      ;search history calls
      ;

      push IE_History1
      call ListFiles

      push IE_History2
      call ListFiles

      push IE_History3
      call ListFiles

    .exit:
     ret
endp

proc AddCRNL buffer, size
     push edx
     push ecx
     mov edx, [buffer]
     xor ecx,ecx

     cmp byte [edx+ecx],0
     jz .null
     jmp .continue

     .null:
       cmp ecx,0
       jz .exit

     .continue:
      inc ecx
      cmp ecx,[size]
      jae .exit
      cmp byte [edx+ecx],0
      jz .replace
      jmp .continue

     .replace:
      mov byte [edx+ecx],13
      mov byte [edx+ecx+1],10
      mov byte [edx+ecx+2],0


     .exit:
         pop ecx
         pop edx
         mov esp,ebp
         pop ebp
         ret 0x8

endp

proc AddCRNLW buffer, size
     push edx
     push ecx
     mov edx, [buffer]
     xor ecx,ecx

     cmp word [edx+ecx],0
     jz .null
     jmp .continue

     .null:
       cmp ecx,0
       jz .exit

     .continue:
      add ecx,2
      cmp ecx,[size]
      jae .exit
      cmp word [edx+ecx],0
      jz .replace
      jmp .continue

     .replace:
      mov word [edx+ecx],13
      mov word [edx+ecx+2],10
      mov word [edx+ecx+4],0


     .exit:
         pop ecx
         pop edx
         mov esp,ebp
         pop ebp
         ret 0x8

endp

proc strcmp str1,str2
     push edx
     push ebx
     push ecx

     mov edx,[str1]
     mov ebx,[str2]
     xor ecx,ecx

    .L1:
     mov ah,byte [edx+ecx]
     mov al,byte [ebx+ecx]

     cmp ah,0
     jz .equal
     cmp ah,al
     jnz .not_equal
     inc ecx
     jmp .L1



     .not_equal:
      mov eax,-1
      jmp .exit

     .equal:
      mov eax,0
      jmp .exit

    .exit:
     pop ecx
     pop ebx
     pop edx
     mov esp,ebp
     pop ebp
     ret 8
endp

proc IsMetaData str
    push edx
    push ecx
    push ebx
    xor ecx,ecx
    xor eax,eax
    ;0x24 = $
    ;0x49 = I


    mov edx, [str]
    mov bl, byte [edx+ecx]
    cmp bl,24h
    jnz .exit
    inc ecx
    mov bl, byte [edx+ecx]
    cmp bl,49h
    jnz .exit
    xor eax,1

   .exit:
    pop ebx
    pop ecx
    pop edx

    mov esp,ebp
    pop ebp
    ret 4
endp

proc RetFileName path
     push edx
     push ecx
     push esi

     xor ecx,ecx
     mov edx,[path]
    .L1:
     mov ax,word [edx+ecx]
     cmp ax,0x0000
     jz .exit
     cmp ax,0x005C
     jz .equal
     add ecx,2
     jmp .L1

    .equal:
     mov esi,ecx
     add ecx,2
     jmp .L1

    .exit:
     add edx,esi
     add edx,2
     mov eax,edx

     pop esi
     pop ecx
     pop edx
     mov esp,ebp
     pop ebp
     ret 4

endp

proc UnicodeToAscii buf, src
    push edx
    push esi
    push edi
    push ecx
    mov edx, [buf]
    mov esi, [src]
    xor edi, edi
    xor ecx, ecx

   .L1:
    mov ax, word [esi+edi]
    cmp ax, 0x0000
    jz .null_terminate
    shl ax, 8
    mov byte [edx+ecx], ah
    inc ecx
    add edi, 2
    jmp .L1

   .null_terminate:
    mov byte [edx+ecx], 0x00

   .exit:
    pop ecx
    pop edi
    pop esi
    pop edx
    mov esp,ebp
    pop ebp
    ret 8
endp


proc ListFilesRecycle path
     locals
      data WIN32_FIND_DATA ?
      hand dd ?
      tmp db "\*",0
      back_slash db "\",0
      root_dir db "..",0
      curr_dir db ".",0
      space_char db "   ",0
      open_brac db "[",0
      closed_brac db "]",0
      tmpbuf db 260 dup(?)
      newbuf db 1000 dup(?)
      testbuf db 260 dup(?)
      readbytes dd ?
      term db 13,10,0
      File_Handle dd ?
     endl
     push edx
     push ebx
     push ecx
     xor ecx,ecx

     push 260
     push [path]
     lea edx,[tmpbuf]
     push edx
     call StrCpy

     push 260
     lea edx,[tmp]
     push edx
     lea edx,[tmpbuf]
     push edx
     call StrCat
     invoke FindFirstFile,addr tmpbuf,addr data
     cmp eax,INVALID_HANDLE_VALUE
     jz .exit
     mov [hand],eax
     mov eax, [data.dwFileAttributes]
     and eax, FILE_ATTRIBUTE_DIRECTORY
     jz .file
     jnz .directory
    .next:

     invoke FindNextFile,[hand],addr data
     test eax,eax
     jz .exit
     mov eax, [data.dwFileAttributes]
     and eax, FILE_ATTRIBUTE_DIRECTORY
     jz .file
     jnz .directory
    .directory:
      lea edx, [data.cFileName]
      push edx
      lea edx, [curr_dir]
      push edx
      call strcmp
      cmp eax,0
      jz .next

      lea edx, [data.cFileName]
      push edx
      lea edx, [curr_dir]
      push edx
      call strcmp
      cmp eax,0
      jz .next

      push 260
      push [path]
      lea eax,[tmpbuf]
      push eax
      call StrCpy

      push 260
      lea edx,[back_slash]
      push edx
      lea edx,[tmpbuf]
      push edx
      call StrCat

      push 260
      lea edx, [data.cFileName]
      push edx
      lea edx,[tmpbuf]
      push edx
      call StrCat

      lea edx,[tmpbuf]
      push edx
      call ListFiles

      jmp .next
    .file:
       lea edx, [data.cFileName]
       push edx
       call IsMetaData
       cmp eax,1
       jnz .next

       push 260
       push [path]
       lea eax,[tmpbuf]
       push eax
       call StrCpy


       push 260
       lea edx,[back_slash]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat


       push 260
       lea edx, [data.cFileName]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat

       invoke CreateFile,addr tmpbuf,GENERIC_READ,\
       0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
       cmp eax,INVALID_HANDLE_VALUE
       jz .next
       mov [File_Handle],eax

       invoke ReadFile,[File_Handle],addr newbuf,1000,addr readbytes,NULL
       cmp eax,0
       jz .next

       ;invoke SendMessage,[Edit_Hwnd],WM_GETTEXTLENGTH,0,0
       ;invoke SendMessage,[Edit_Hwnd],EM_SETSEL,eax,eax

       invoke CloseHandle,[File_Handle]

       lea eax,[newbuf]
       lea edx,[eax+RecycleMetaNew.FileName]
       push edx
       call RetFileName

       push eax
       lea edx, [testbuf]
       push edx
       call UnicodeToAscii

       push 260
       lea edx, [space_char]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat

       push 260
       lea edx, [open_brac]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat

       push 260
       lea edx, [testbuf]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat

       push 260
       lea edx, [closed_brac]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat

       push 260
       lea eax, [tmpbuf]
       push eax
       call AddCRNL
       invoke SendMessage,[Edit_Hwnd],EM_REPLACESEL,FALSE,eax
       mov ecx, [File_Cnt]
       inc ecx
       mov [File_Cnt], ecx
       jmp .next

    .exit:
	 invoke FindClose,[hand]
     pop ecx
     pop ebx
     pop edx
     mov esp,ebp
     pop ebp
     ret 0x4
endp

proc ListFiles path
     locals
      data WIN32_FIND_DATA ?
      hand dd ?
      tmp db "\*",0
      back_slash db "\",0
      root_dir db "..",0
      curr_dir db ".",0
      tmpbuf db 260 dup(?)
      term db 13,10,0
     endl
     push edx
     push ebx
     push ecx
     xor ecx,ecx

     push 260
     push [path]
     lea edx,[tmpbuf]
     push edx
     call StrCpy

     push 260
     lea edx,[tmp]
     push edx
     lea edx,[tmpbuf]
     push edx
     call StrCat
     invoke FindFirstFile,addr tmpbuf,addr data
     cmp eax,INVALID_HANDLE_VALUE
     jz .exit
     mov [hand],eax
     mov eax, [data.dwFileAttributes]
     and eax, FILE_ATTRIBUTE_DIRECTORY
     jz .file
     jnz .directory
    .next:

     invoke FindNextFile,[hand],addr data
     test eax,eax
     jz .exit
     mov eax, [data.dwFileAttributes]
     and eax, FILE_ATTRIBUTE_DIRECTORY
     jz .file
     jnz .directory
    .directory:
      lea edx, [data.cFileName]
      push edx
      lea edx, [curr_dir]
      push edx
      call strcmp
      cmp eax,0
      jz .next

      lea edx, [data.cFileName]
      push edx
      lea edx, [curr_dir]
      push edx
      call strcmp
      cmp eax,0
      jz .next

      push 260
      push [path]
      lea eax,[tmpbuf]
      push eax
      call StrCpy

      push 260
      lea edx,[back_slash]
      push edx
      lea edx,[tmpbuf]
      push edx
      call StrCat


      push 260
      lea edx, [data.cFileName]
      push edx
      lea edx,[tmpbuf]
      push edx
      call StrCat

      lea edx,[tmpbuf]
      push edx
      call ListFiles

      jmp .next
    .file:
       push 260
       push [path]
       lea eax,[tmpbuf]
       push eax
       call StrCpy


       push 260
       lea edx,[back_slash]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat


       push 260
       lea edx, [data.cFileName]
       push edx
       lea edx,[tmpbuf]
       push edx
       call StrCat

       invoke SendMessage,[Edit_Hwnd],WM_GETTEXTLENGTH,0,0
       invoke SendMessage,[Edit_Hwnd],EM_SETSEL,eax,eax
       lea edx, [tmpbuf]
       push 260
       push edx
       call AddCRNL
       invoke SendMessage,[Edit_Hwnd],EM_REPLACESEL,FALSE,edx
       mov ecx, [File_Cnt]
       inc ecx
       mov [File_Cnt], ecx
       jmp .next
    .exit:
     pop ecx
     pop ebx
     pop edx
     mov esp,ebp
     pop ebp
     ret 0x4
endp

proc DisplayCnt cnt
     locals
         buf db 100 dup(?)
         FormatStr db "File count: %d",0
     endl
     invoke sprintf,addr buf,addr FormatStr,[cnt]
     invoke SetWindowText,[Cnt_Hwnd],addr buf

     mov esp,ebp
     pop ebp
     ret 4
endp

section '.data' data readable writable
        wc WNDCLASSEX
        hWnd dd ?
        TreeView dd ?
        _class db "DiskCleaner",0
        _title db "DiskCleaner",0
        msg MSG ?
        hIcon dd ?
        hIconMain dd ?
        TreeViewStr db "SysTreeView32",0
        tvinsert TV_INSERTSTRUCT ?
        tv TV_ITEM ?
        _System db "System",0
        Root dd ?
        Second dd ?
        _Recycle db "Recycle bin",0
        _Temp db "Temporary files",0
        _Internet db "Internet Explorer",0
        _Cookie db "Cookies",0
        _Form db "Form history",0
        _History db "History",0
        _Clip db "Clipboard",0
        _hand dd ?
        hit TVHITTESTINFO 0
        pt POINT ?
        _Recycle_path db 260 dup(?)
        View_Hwnd dd ?
        Edit_Hwnd dd ?
        Delete_Hwnd dd ?
        buffy db 260 dup(?)
        hThread_System dd 0
                       dd 0
        hf dd ?
        LocalSettings db 260 dup(?)
        Temp db 260 dup(?)
        WinTmp db 260 dup(?)
        Cnt_Hwnd dd ?
        File_Cnt dd 0
        IE_Cookies db 260 dup(?)
        IE_Cookies2 db 260 dup(?)
        IE_History1 db 260 dup(?)
        IE_History2 db 260 dup(?)
        IE_History3 db 260 dup(?)
        ;pDesktop LPSHELLFOLDER ?



section '.idata' import readable
 library kernel32, 'kernel32.dll',\
         user32, 'user32.dll', \
         gdi32, 'gdi32.dll',\
         comctrl32, 'comctl32.dll',\
         advapi32, 'advapi32.dll',\
         mscvrt, 'msvcrt.dll'
 import advapi32,\
        OpenProcessToken, 'OpenProcessToken',\
        GetTokenInformation, 'GetTokenInformation',\
        ConvertSidToStringSid, 'ConvertSidToStringSidA'
 import user32,\
        RegisterClassEx, 'RegisterClassExA', \
        ShowWindow, 'ShowWindow', \
        CreateWindowEx, 'CreateWindowExA', \
        UpdateWindow, 'UpdateWindow', \
        GetMessage, 'GetMessageA', \
        TranslateMessage, 'TranslateMessage', \
        DispatchMessage, 'DispatchMessageA', \
        MessageBox, 'MessageBoxA', \
        DefWindowProc, 'DefWindowProcA', \
        PostQuitMessage, 'PostQuitMessage', \
        LoadIcon, 'LoadIconA', \
        LoadCursor, 'LoadCursorA',\
        LoadMenu, 'LoadMenuA',\
        SendMessage, 'SendMessageA',\
        GetClientRect, 'GetClientRect',\
        DialogBoxParam, 'DialogBoxParamA',\
        EndDialog, 'EndDialog',\
        LoadImage, 'LoadImageA',\
        GetSystemMetrics, 'GetSystemMetrics',\
        GetMessagePos, 'GetMessagePos',\
        MapWindowPoints, 'MapWindowPoints',\
        PostMessage, 'PostMessageA',\
        EnumChildWindows, 'EnumChildWindows',\
        SetWindowText, 'SetWindowTextA',\

 import kernel32,\
        GetModuleHandle,'GetModuleHandleA',\
        ExitProcess,'ExitProcess',\
        CreateFile, 'CreateFileA',\
        ReadFile, 'ReadFile',\
        FormatMessage, 'FormatMessageA',\
        GetLastError, 'GetLastError',\
        LocalFree, 'LocalFree',\
        HeapAlloc, 'HeapAlloc',\
        HeapFree, 'HeapFree',\
        GetProcessHeap, 'GetProcessHeap',\
        GetCurrentProcess, 'GetCurrentProcess',\
        FindFirstFile, 'FindFirstFileA',\
        FindNextFile, 'FindNextFileA',\
        FindClose, 'FindClose',\
        CreateThread, 'CreateThread',\
        WaitForSingleObject, 'WaitForSingleObject',\
        CloseHandle, 'CloseHandle',\
        ExpandEnvironmentStrings, 'ExpandEnvironmentStringsA',\
        WaitForMultipleObjects, 'WaitForMultipleObjects',\
        DeleteFile, 'DeleteFileA'
 import gdi32,\
        CreateFont, 'CreateFontA',\
        CreateSolidBrush, 'CreateSolidBrush'
 import comctrl32,\
        InitCommonControls, 'InitCommonControls'
 import mscvrt,\
        sprintf, 'sprintf'


section '.rsrc' resource data readable

 directory RT_MENU,menus,\
           RT_ICON, icons,\
           RT_GROUP_ICON, group_icons,\
           RT_DIALOG, dialogs,\
           RT_MANIFEST,manifests

 resource menus,\
          IDR_MENU,LANG_ENGLISH+SUBLANG_DEFAULT,main_menu

 resource icons,\
           IDR_ICON,LANG_NEUTRAL,icon_data

 resource group_icons,\
           IDR_ICON,LANG_NEUTRAL,main_icon

 resource dialogs,\
           37,LANG_ENGLISH+SUBLANG_DEFAULT,about_dlg
 resource manifests,\
           1,LANG_ENGLISH+SUBLANG_DEFAULT,manifest

 menu main_menu
      menuitem '&File',0,MFR_POPUP
       menuitem 'E&xit',IDM_EXIT,MFR_END
      menuitem '&Help',0,MFR_POPUP+MFR_END
       menuitem '&About...',IDM_ABOUT,MFR_END

 icon main_icon,icon_data,'eraser.ico'

 dialog about_dlg,'About',25,25,150,80,\
 DS_MODALFRAME+WS_MINIMIZEBOX+WS_POPUP+WS_VISIBLE+WS_CAPTION+WS_SYSMENU,0,0,"MS Shell Dlg",\
 10
    dialogitem 'STATIC','DiskCleaner, Version 1.0',54,40,20,86,15,WS_VISIBLE
    dialogitem 'BUTTON','OK',IDOK,50,50,50,14,WS_VISIBLE+WS_TABSTOP+BS_DEFPUSHBUTTON
    dialogitem  "STATIC", IDR_ICON, 101, 16, 15, 0, 0, SS_ICON+WS_VISIBLE, 0
 enddialog

 resdata manifest
   db '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',13,10
   db '<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">',13,10
   db '<assemblyIdentity name="DiskCleaner.exe" processorArchitecture="x86" version="5.1.0.0" type="win32"/> ',13,10
   db '<description>no</description>',13,10
   db '<dependency>',13,10
   db '<dependentAssembly>',13,10
   db '<assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" version="6.0.0.0" processorArchitecture="x86" publicKeyToken="6595b64144ccf1df" language="*" />',13,10
   db '</dependentAssembly>',13,10
   db '</dependency>',13,10
   db '</assembly>',13,10
 endres