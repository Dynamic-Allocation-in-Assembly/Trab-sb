
SECTION .data
brk:        dq 0        ; current brk
base_brk:   dq 0        ; base of heap (initial brk)
heap_start: dq 0        ; start of heap (we set to base_brk in setup_brk)

SECTION .text
global setup_brk
global dismiss_brk
global expand_brk
global memory_alloc
global memory_free

; syscall numbers for x86_64 Linux
%define SYS_brk 12

; -------------------------
; void setup_brk()
; sets base_brk = brk(0); brk = base_brk; heap_start = base_brk
; returns nothing
; -------------------------
setup_brk:
    push rbp
	mov rbp, rsp

	; brk(0)
    xor     rdi, rdi        ; rdi = 0
    mov     rax, SYS_brk
    syscall
    ; returned address in rax
    mov     [rel base_brk], rax
    mov     [rel brk], rax
    mov     [rel heap_start], rax

	pop rbp
	ret

; -------------------------
; void dismiss_brk()
; sys_brk(base_brk); brk = base_brk
; -------------------------
dismiss_brk:
	push rbp
	mov rbp, rsp

	mov     rdi, [rel base_brk]
    mov     rax, SYS_brk
    syscall

    mov     [rel brk], rax

	pop rbp
|---ret

; -------------------------
; int expand_brk(int y)
; returns antigo = old brk in rax
; behavior: proximo = brk + 9 + y; sys_brk(proximo); update brk; return antigo
; arg: y in edi (32-bit)
; -------------------------
expand_brk:
    push    rbp
    mov     rbp, rsp

	; save antigo = brk
    mov     rax, [rel brk]      ; antigo in rax (return value)
    mov     rbx, rax            ; rbx = antigo
    ; compute proximo = brk + 9 + y
    mov     rcx, rax            ; rcx = brk
    mov     rdx, rdi            ; rdx = y
    add     rcx, 9
    add     rcx, rdx
    ; call brk(proximo)
    mov     rdi, rcx
    mov     rax, SYS_brk
    syscall
    ; syscall returns new brk in rax; store it
    mov     [rel brk], rax
    ; return antigo in rax (we had saved in rbx)
    mov     rax, rbx
    pop     rbp
    ret

; -------------------------
; void *memory_alloc(unsigned long y)
; arg: y in rdi (we'll use rdi)
; returns pointer to payload (melhor+9) in rax
; Worst-fit search across blocks from heap_start to brk
; -------------------------
memory_alloc:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi        ; r12 = requested size y

    ; initialize melhor = 0, melhor_tam = 0
    xor     r13, r13        ; r13 = melhor (0)
    xor     r14, r14        ; r14 = melhor_tam (0)

    ; p = heap_start
    mov     rsi, [rel heap_start]   ; rsi = p (cursor)
    ; brk in rdx for comparison
    mov     rdx, [rel brk]

.loop_find:
    cmp     rsi, rdx
    jge     .not_found      ; if p >= brk, stop

    ; uso = [p]  (byte)
    movzx   eax, byte [rsi]
    cmp     al, 0
    jne     .advance_cursor ; if uso != 0 (in use), skip

    ; tam = *(ulong*)(p+1)
    mov     rax, [rsi + 1] ; rax = tam (qword)
    ; compare tam >= y ?
    mov     rbx, r12
    cmp     rax, rbx
    jb      .advance_cursor

    ; if tam > melhor_tam then update melhor, melhor_tam
    cmp     rax, r14
    jle     .advance_cursor

    mov     r13, rsi        ; melhor = p
    mov     r14, rax        ; melhor_tam = tam

.advance_cursor:
    ; p += 9 + tam
    ; need tam for increment: read tam qword
    mov     rax, [rsi + 1]
    add     rsi, 9
    add     rsi, rax
    jmp     .loop_find

.not_found:
    ; if melhor != 0
    test    r13, r13
    jne     .use_best

    ; else: expand_brk(y)
    ; call expand_brk with y in edi
    mov     edi, r12d
    call    expand_brk      ; returns antigo in rax
    mov     rsi, rax        ; p = antigo
    ; set [p] = 1
    mov     byte [rsi], 1
    ; *(ulong*)(p+1) = y
    mov     [rsi + 1], r12
    ; return p+9 (pointer to payload)
    lea     rax, [rsi + 9]
    ; restore and return
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.use_best:
    ; found melhor at r13, melhor_tam in r14
    ; if (melhor_tam >= y + 9 + 1) -> split possible
    mov     rax, r14        ; rax = melhor_tam
    mov     rbx, r12
    add     rbx, 9
    add     rbx, 1          ; required leftover threshold (as in pseudocode)
    cmp     rax, rbx
    jb      .alloc_whole

    ; split:
    ; [melhor] = 1
    mov     byte [r13], 1
    ; *(ulong*)(melhor+1) = y
    mov     [r13 + 1], r12
    ; novo_bloco = melhor + 9 + y
    lea     rsi, [r13 + 9]
    add     rsi, r12
    ; [novo] = 0
    mov     byte [rsi], 0
    ; *(ulong*)(novo+1) = melhor_tam - 9 - y
    mov     rax, r14
    sub     rax, 9
    sub     rax, r12
    mov     [rsi + 1], rax
    ; return melhor+9
    lea     rax, [r13 + 9]
    ; restore and return
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.alloc_whole:
    ; mark block as used: [melhor] = 1
    mov     byte [r13], 1
    ; return melhor+9
    lea     rax, [r13 + 9]
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; -------------------------
; int memory_free(void *pointer)
; arg: pointer -> rdi
; compute p = pointer - 9; *p = 0; return 0 in rax
; -------------------------
memory_free:
    push    rbp
    mov     rbp, rsp
    ; p = pointer - 9
    mov     rax, rdi
    sub     rax, 9
    ; *p = 0
    mov     byte [rax], 0
    xor     eax, eax    ; return 0
    pop     rbp
    ret

