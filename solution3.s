SECTION .data
brk:        dq 0
base_brk:   dq 0

SECTION .text
global setup_brk
global dismiss_brk
global memory_alloc
global memory_free

%define SYS_brk 12

; Função OK!
setup_brk:
    push rbp
    mov rbp, rsp

    xor rdi, rdi           ; arg = 0
    ; coloca 12 em RAX e chama a SysCall
    mov rax, SYS_brk
    syscall                ; returns current brk

    mov [base_brk], rax
    mov [brk], rax

    pop rbp
    ret

; Função OK!
dismiss_brk:
    push rbp
    mov rbp, rsp

    ; RDI = argumento da syscall.
    mov rdi, [base_brk]
    mov rax, SYS_brk
    syscall

    ; coloca em brk o valor da base, passo para RAX:
    mov [brk], rax

    pop rbp
    ret

; -------------------------------------------------------
; void *memory_alloc(unsigned long y)
; Função OK!
memory_alloc:
    push rbp
    mov rbp, rsp

    push r12
    push r13
    push r14

    ; colocando em R12 o valor de "y" (argumento da função)
    mov r12, rdi

    ; R13 = Melhor = Ponteiro para o começo dos metadados do melhor bloco disponível:
    xor r13, r13
    ; R14 = Melhor_tam = Tamanho do melhor bloco disponível. Se melhor_tam = 0, não há blocos disponíveis antes de BRK:
    xor r14, r14

    ; Guardando em RSI a base de brk
    mov rsi, [base_brk]
    ; Guardando em RDX o valor de brk:
    mov rdx, [brk]

; Função OK!
.loop:
    ; Comparando base de brk com brk
    cmp rsi, rdx
    jge .confere_achou

    ; Pegando o primeiro byte da base_brk (byte de uso):
    movzx eax, byte [rsi]
    ; Pegando o tamanho do bloco (8 bytes do uso) e guardando em RCX:
    mov rcx, [rsi + 1]

    ; Se bloco não estiver sendo usado, pula para Advance!
    cmp al, 0
    jne .advance

    ; Comparando o tamanho que a gente quer colocar com o disponível no bloco:
    cmp rcx, r12
    ; Se tamanho insuficiente: pula para o próximo!
    jb .advance

    ; Vendo se achamos um tamanho melhor do que melhor_tam. WORST-FIT:
    cmp rcx, r14
    ; Se tamanho disponível encontrado é menor do que melhor_tam, vamos para o próximo bloco:
    jle .advance

    ; Se chegamos até aqui, então vamos mudar as variáveis melhor e melhor_tam:
    mov r13, rsi
    mov r14, rcx

; Função OK!
.confere_achou:
    cmp r14, 0
    jne .middle_block
    jmp .no_middle_block

; Função OK!
.advance:
    ; Pegando o tamanho e colocando em rcx:
    mov rcx, [rsi + 1]
    add rsi, 9
    add rsi, rcx
    jmp .loop

; Função OK!
.middle_block:
    ; Colocando o melhor_tam em RCX:
    mov rcx, r14
    ; Colocando em RBX o nosso y:
    mov rbx, r12
    ; Adicionando +10 para ver se conseguimos ou não fazer o split:
    add rbx, 9
    add rbx, 1

    ; Comparando se o tamanho do bloco é menor do que y+10:
    cmp rcx, rbx
    jb .use_whole

; Função OK!
.split_block:
    ; Colocando 1 no ponteiro do começo dos metadados do bloco livre (Melhor):
    mov byte [r13], 1
    ; Colocando y (tamanho do bloco que queremos reservar) nos metadados do tamanho do bloco disponível:
    mov [r13 + 1], r12

    ; Vai até o tamanho ocupado por y e coloca esse começo em RSI:
    lea rsi, [r13 + 9 + r12]
    ; Colocando o primeiro byte do novo bloco como 0:
    mov byte [rsi], 0
    ; Tam do novo bloco = tam_bloco_total - 9 - y:
    mov rax, r14
    sub rax, 9
    sub rax, r12
    ; Colocando o meta dado de tamanho no novo bloco:
    mov [rsi + 1], rax

    ; Colocando o valor do começo dos dados no retorno (RAX):
    lea rax, [r13 + 9]
    jmp .done

; Função OK!
.use_whole:
    ; Colocando 1 no ponteiro do começo dos metadados do bloco livre (Melhor):
    mov byte [r13], 1
    ; Colocando y (tamanho do bloco que queremos reservar) nos metadados do tamanho do bloco disponível:
    mov [r13 + 1], r12
    ; Colocando o valor do começo dos dados no retorno (RAX):
    lea rax, [r13 + 9]
    jmp .done

; Função OK!
.no_middle_block:
    ; Guarda em RAX o ponteiro brk:
    mov rax, [brk]
    ; Guardando em RCX o tamanho do último bloco ocupado:
    mov rcx, [rax - 8]
    ; Fazendo as contas para colocar o BRK no começo do próximo bloco:
    add rcx, 9
    add rax, rcx
    ; Subindo BRK:
    mov [brk], rax

    ; Colocando o byte de uso no metadado do novo bloco:
    mov byte [rax - 9], 1
    ; Coloca o valor do tamanho(y) no metadado do tamanho do bloco:
    mov [rax - 8], r12

    ; Colocando o valor retornado da função (endereço do começo dos dados do novo bloco):
    mov rax, [brk]
    jmp .done

.done:
    pop r14
    pop r13
    pop r12
	pop rbp
    ret

memory_free:
	push rbp
    mov rbp, rsp

    ; Colocando em rax o valor do começo dos dados do bloco que quero retirar:
    mov rax, rdi
    ; Descrescendo 9 (indo ao byte de uso do bloco):
    sub rax, 9
    ; Colocando 0 no byte de uso:
    mov byte [rax], 0
    ; Retornando 0:
    xor eax, eax

	pop rbp
    ret
