SECTION .data
brk:        dq 0
base_brk:   dq 0

SECTION .text
global setup_brk
global dismiss_brk
global memory_alloc
global memory_free

%define SYS_brk 12


; -------------------------------------------------------
; void setup_brk()
; base_brk = sys_brk(0)
; brk = base_brk
; -------------------------------------------------------
setup_brk:
    push rbp
    mov rbp, rsp

	xor rdi, rdi           ; arg = 0
    mov rax, SYS_brk
    syscall                ; returns current brk

    mov [base_brk], rax
    mov [brk], rax

	pop rbp
    ret

; -------------------------------------------------------
; void dismiss_brk()
; sys_brk(base_brk)
; brk = base_brk
; -------------------------------------------------------
dismiss_brk:
    push rbp
    mov rbp, rsp

	mov rdi, [base_brk]    ; argument
    mov rax, SYS_brk
    syscall

	mov [brk], rax

	pop rbp
    ret

; -------------------------------------------------------
; void *memory_alloc(unsigned long y)
; -------------------------------------------------------
memory_alloc:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi           ; y

    xor r13, r13           ; melhor = NULL
    xor r14, r14           ; melhor_tam = 0

    mov rsi, [base_brk]    ; p = base_brk
    mov rdx, [brk]         ; limite

.loop:
    cmp rsi, rdx
    jge .no_middle_block

    movzx eax, byte [rsi]  ; uso
    mov rcx, [rsi + 1]     ; tam

    cmp al, 0
    jne .advance

    cmp rcx, r12
    //Jump if Less unsigned:
	jb .advance

    cmp rcx, r14
    jle .advance

	//Chegou aqui, possui um bloco válido:
    mov r13, rsi           ; melhor
    mov r14, rcx           ; melhor_tam

.advance:
    mov rcx, [rsi + 1]
    add rsi, 9
    add rsi, rcx
    jmp .loop


; -------------------------------------------------------
; Achou bloco no meio
; -------------------------------------------------------
.middle_block:
    mov rcx, r14
    mov rbx, r12
    add rbx, 9
    add rbx, 1             ; y + 9 + 1

    cmp rcx, rbx
    jb .use_whole

.split_block:
    mov byte [r13], 1
    mov [r13 + 1], r12

    lea rsi, [r13 + 9 + r12]
    mov byte [rsi], 0
    mov rax, r14
    sub rax, 9
    sub rax, r12
    mov [rsi + 1], rax

    lea rax, [r13 + 9]
    jmp .done


.use_whole:
    mov byte [r13], 1
    mov [r13 + 1], r12
    lea rax, [r13 + 9]
    jmp .done


; -------------------------------------------------------
; Não achou bloco no meio
; brk += [brk-8] + 9
; [brk-9] = 1
; [brk-8] = y
; return brk
; -------------------------------------------------------
.no_middle_block:
    test r13, r13
    jnz .middle_block

    mov rax, [brk]
    mov rcx, [rax - 8]     ; tam existente
    add rcx, 9
    add rax, rcx
    mov [brk], rax

    mov byte [rax - 9], 1
    mov [rax - 8], r12

    mov rax, [brk]
    jmp .done


.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret


; -------------------------------------------------------
; int memory_free(void *pointer)
; * (pointer - 9) = 0
; -------------------------------------------------------
memory_free:
    mov rax, rdi
    sub rax, 9
    mov byte [rax], 0
    xor eax, eax
    ret

