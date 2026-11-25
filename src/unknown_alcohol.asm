format PE64 DLL
entry DllMain

include 'win64a.inc'

UP_VAL_I32 = 2
UP_VAL_F32 = 4
UP_VAL_STR = 6
UP_VAL_OBJ = 7
UP_HOOK_BEFORE = 1

NUM_BODIES = 8
BS_INSTANCE = 0
BS_ACTIVE = 4
BS_HANDLE = 8
BS_LEVEL = 16
BS_SIZE = 24

section '.text' code readable executable

DllMain:
    mov eax, 1
    ret

UP_GetModule:
    lea rax, [module_description]
    ret

module_init:
    sub rsp, 72
    mov [g_host], rcx
    test rdx, rdx
    jz .no_user
    mov qword [rdx], 0
.no_user:
    mov ecx, 2
    lea rdx, [msg_loaded]
    call host_log
    xor eax, eax
    add rsp, 72
    ret

install_hook:
    sub rsp, 72
    mov rax, [g_host]
    mov rcx, [rax+8]
    lea rdx, [type_water_container]
    lea r8, [method_drink]
    lea r9, [params_drink]
    mov dword [rsp+32], UP_HOOK_BEFORE
    lea r11, [on_drink]
    mov [rsp+40], r11
    mov qword [rsp+48], 0
    call qword [rax+216]
    test eax, eax
    jle .failed
    mov dword [g_hook_installed], 1
    mov ecx, 2
    lea rdx, [msg_hook_ok]
    call host_log
    jmp .done
.failed:
    mov ecx, 4
    lea rdx, [msg_hook_failed]
    call host_log
.done:
    add rsp, 72
    ret

module_tick:
    sub rsp, 40
    movss [g_dt], xmm1
    cmp dword [g_hook_installed], 0
    jne .tick
    movss xmm2, [g_hook_timer]
    subss xmm2, xmm1
    movss [g_hook_timer], xmm2
    xorps xmm3, xmm3
    comiss xmm2, xmm3
    ja .tick
    movss xmm2, [c_hook_retry]
    movss [g_hook_timer], xmm2
    call install_hook
.tick:
    call tick_all
    add rsp, 40
    ret

module_shutdown:
    sub rsp, 72
    lea rax, [body_states]
    mov [rsp+32], rax
    mov dword [rsp+40], NUM_BODIES
.loop:
    mov rdx, [rsp+32]
    cmp dword [rdx+BS_ACTIVE], 0
    je .next
    mov rcx, [rdx+BS_HANDLE]
    test rcx, rcx
    jz .clear
    call host_release
.clear:
    mov rdx, [rsp+32]
    mov dword [rdx+BS_ACTIVE], 0
    mov dword [rdx+BS_INSTANCE], 0
    mov qword [rdx+BS_HANDLE], 0
    mov dword [rdx+BS_LEVEL], 0
.next:
    add qword [rsp+32], BS_SIZE
    dec dword [rsp+40]
    jnz .loop
    mov ecx, 2
    lea rdx, [msg_unloaded]
    call host_log
    add rsp, 72
    ret

on_drink:
    sub rsp, 40
    cmp dword [rcx+8], UP_HOOK_BEFORE
    jne .done
    cmp dword [rcx+12], 2
    jb .done
    mov rax, [rcx+16]
    cmp dword [rax], UP_VAL_OBJ
    jne .done
    cmp dword [rax+32], UP_VAL_F32
    jne .done
    mov rdx, [rax+8]
    movss xmm0, [rax+40]
    mov rcx, [rcx+32]
    call process_drink
.done:
    xor eax, eax
    add rsp, 40
    ret

process_drink:
    sub rsp, 296
    mov [rsp+48], rcx
    mov [rsp+56], rdx
    lea rcx, [rsp+64]
    call make_f32
    mov rcx, [rsp+48]
    lea rdx, [method_calculate_drain]
    lea r8, [rsp+64]
    mov r9d, 1
    lea r10, [rsp+96]
    call host_invoke
    test eax, eax
    js .done
    cmp dword [rsp+96], UP_VAL_OBJ
    jne .done
    mov rax, [rsp+104]
    test rax, rax
    jz .done
    mov [rsp+128], rax
    mov rcx, [rsp+48]
    lea rdx, [field_stack]
    lea r8, [rsp+136]
    call host_get_field
    test eax, eax
    js .release_drain
    cmp dword [rsp+136], UP_VAL_OBJ
    jne .release_drain
    mov rax, [rsp+144]
    test rax, rax
    jz .release_drain
    mov [rsp+168], rax
    mov rcx, [rsp+128]
    lea rdx, [method_get_count]
    xor r8d, r8d
    xor r9d, r9d
    lea r10, [rsp+96]
    call host_invoke
    test eax, eax
    js .release_both
    cmp dword [rsp+96], UP_VAL_I32
    jne .release_both
    mov eax, [rsp+104]
    mov [rsp+176], eax
    mov dword [rsp+180], 0
    mov dword [rsp+184], 0
.loop:
    mov eax, [rsp+180]
    cmp eax, [rsp+176]
    jge .finish
    lea rcx, [rsp+264]
    mov edx, eax
    call make_i32
    mov rcx, [rsp+128]
    lea rdx, [method_get_item]
    lea r8, [rsp+264]
    mov r9d, 1
    lea r10, [rsp+96]
    call host_invoke
    test eax, eax
    js .next
    cmp dword [rsp+96], UP_VAL_F32
    jne .next
    movss xmm0, [rsp+104]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .next
    movss [rsp+188], xmm0
    mov rcx, [rsp+168]
    lea rdx, [method_get_item]
    lea r8, [rsp+264]
    mov r9d, 1
    lea r10, [rsp+96]
    call host_invoke
    test eax, eax
    js .next
    cmp dword [rsp+96], UP_VAL_OBJ
    jne .next
    mov rax, [rsp+104]
    test rax, rax
    jz .next
    mov [rsp+224], rax
    mov rcx, rax
    lea rdx, [field_liquid_id]
    lea r8, [rsp+232]
    call host_get_field
    test eax, eax
    js .release_entry
    cmp dword [rsp+232], UP_VAL_STR
    jne .release_entry
    mov rcx, [rsp+256]
    test rcx, rcx
    jz .release_entry
    lea rdx, [liquid_alcohol]
    call str_eq
    test eax, eax
    jz .release_entry
    movss xmm0, [rsp+188]
    addss xmm0, [rsp+184]
    movss [rsp+184], xmm0
.release_entry:
    mov rcx, [rsp+224]
    call host_release
.next:
    inc dword [rsp+180]
    jmp .loop
.finish:
    mov rcx, [rsp+168]
    call host_release
.release_drain:
    mov rcx, [rsp+128]
    call host_release
    movss xmm0, [rsp+184]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe .done
    mov rcx, [rsp+56]
    call add_points
    jmp .done
.release_both:
    mov rcx, [rsp+168]
    call host_release
    jmp .release_drain
.done:
    add rsp, 296
    ret

add_points:
    sub rsp, 120
    mov [rsp+48], rcx
    movss [rsp+100], xmm0
    mulss xmm0, [c_strength]
    mulss xmm0, [c_points_per_ml]
    movss [rsp+56], xmm0
    mov rcx, [rsp+48]
    lea rdx, [method_get_instance_id]
    xor r8d, r8d
    xor r9d, r9d
    lea r10, [rsp+64]
    call host_invoke
    test eax, eax
    js .done
    cmp dword [rsp+64], UP_VAL_I32
    jne .done
    mov eax, [rsp+72]
    mov [rsp+96], eax
    lea rdx, [body_states]
    mov ecx, NUM_BODIES
.search:
    cmp dword [rdx+BS_ACTIVE], 0
    je .next
    mov eax, [rsp+96]
    cmp dword [rdx+BS_INSTANCE], eax
    je .found
.next:
    add rdx, BS_SIZE
    dec ecx
    jnz .search
    lea rdx, [body_states]
    mov ecx, NUM_BODIES
.find_free:
    cmp dword [rdx+BS_ACTIVE], 0
    je .create
    add rdx, BS_SIZE
    dec ecx
    jnz .find_free
    jmp .done
.create:
    mov eax, [rsp+96]
    mov [rdx+BS_INSTANCE], eax
    mov rcx, [rsp+48]
    mov [rdx+BS_HANDLE], rcx
    mov dword [rdx+BS_LEVEL], 0
    mov dword [rdx+BS_ACTIVE], 1
    mov [rsp+108], rdx
    mov rcx, [rsp+48]
    call host_retain
    mov rdx, [rsp+108]
.found:
    movss xmm0, [rdx+BS_LEVEL]
    addss xmm0, [rsp+56]
    minss xmm0, [c_max_level]
    movss [rdx+BS_LEVEL], xmm0
    mov rcx, [rsp+48]
    lea rdx, [field_sickness]
    lea r8, [rsp+104]
    call get_f32
    test eax, eax
    jz .done
    movss xmm0, [rsp+100]
    mulss xmm0, [c_extra_sickness]
    addss xmm0, [rsp+104]
    mov rcx, [rsp+48]
    lea rdx, [field_sickness]
    call set_f32
.done:
    add rsp, 120
    ret

tick_all:
    sub rsp, 72
    lea rax, [body_states]
    mov [rsp+32], rax
    mov dword [rsp+40], NUM_BODIES
.loop:
    mov rdx, [rsp+32]
    cmp dword [rdx+BS_ACTIVE], 0
    je .next
    mov rcx, rdx
    call tick_one
.next:
    add qword [rsp+32], BS_SIZE
    dec dword [rsp+40]
    jnz .loop
    add rsp, 72
    ret

tick_one:
    sub rsp, 184
    mov [rsp+48], rcx
    mov rdx, rcx
    movss xmm0, [rdx+BS_LEVEL]
    movss xmm1, [g_dt]
    mulss xmm1, [c_decay]
    subss xmm0, xmm1
    movss [rdx+BS_LEVEL], xmm0
    movss [rsp+56], xmm0
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja .alive
    mov rcx, [rdx+BS_HANDLE]
    test rcx, rcx
    jz .clear
    call host_release
.clear:
    mov rdx, [rsp+48]
    mov dword [rdx+BS_ACTIVE], 0
    mov dword [rdx+BS_INSTANCE], 0
    mov qword [rdx+BS_HANDLE], 0
    mov dword [rdx+BS_LEVEL], 0
    add rsp, 184
    ret
.alive:
    mov rax, [rdx+BS_HANDLE]
    mov [rsp+136], rax
    movss xmm0, [rsp+56]
    comiss xmm0, [c_tipsy]
    jb .skip_loosen
    mulss xmm0, [c_slowdown_per_level]
    minss xmm0, [c_max_slowdown]
    xorps xmm1, xmm1
    subss xmm1, xmm0
    movss [rsp+100], xmm1
    mov rcx, [rsp+136]
    lea rdx, [field_stimulant]
    lea r8, [rsp+96]
    call get_f32
    test eax, eax
    jz .no_stim
    movss xmm4, [rsp+96]
    movss xmm3, [rsp+100]
    comiss xmm4, xmm3
    jbe .no_stim
    movaps xmm0, xmm3
    mov rcx, [rsp+136]
    lea rdx, [field_stimulant]
    call set_f32
.no_stim:
    mov rcx, [rsp+136]
    lea rdx, [field_happiness]
    lea r8, [rsp+96]
    call get_f32
    test eax, eax
    jz .skip_loosen
    movss xmm0, [g_dt]
    mulss xmm0, [c_cheer]
    addss xmm0, [rsp+96]
    mov rcx, [rsp+136]
    lea rdx, [field_happiness]
    call set_f32
.skip_loosen:
    movss xmm0, [rsp+56]
    comiss xmm0, [c_drunk]
    jb .skip_stagger
    subss xmm0, [c_drunk]
    mulss xmm0, [c_stumble]
    mulss xmm0, [g_dt]
    movss [rsp+100], xmm0
    call rand01
    movss xmm1, [rsp+100]
    comiss xmm0, xmm1
    jae .no_ragdoll
    mov rcx, [rsp+136]
    lea rdx, [method_ragdoll]
    xor r8d, r8d
    xor r9d, r9d
    xor r10d, r10d
    call host_invoke
.no_ragdoll:
.skip_stagger:
    movss xmm0, [rsp+56]
    comiss xmm0, [c_sick]
    jb .skip_sicken
    subss xmm0, [c_sick]
    mulss xmm0, [c_vomit_chance]
    mulss xmm0, [g_dt]
    movss [rsp+100], xmm0
    call rand01
    movss xmm1, [rsp+100]
    comiss xmm0, xmm1
    jae .no_vomit
    mov rcx, [rsp+136]
    lea rdx, [field_vomiter]
    lea r8, [rsp+104]
    call host_get_field
    test eax, eax
    js .no_vomit
    cmp dword [rsp+104], UP_VAL_OBJ
    jne .no_vomit
    mov rcx, [rsp+112]
    test rcx, rcx
    jz .no_vomit
    mov [rsp+144], rcx
    lea rdx, [method_vomit]
    xor r8d, r8d
    xor r9d, r9d
    xor r10d, r10d
    call host_invoke
    mov rcx, [rsp+144]
    call host_release
.no_vomit:
    mov rcx, [rsp+136]
    lea rdx, [field_consciousness]
    lea r8, [rsp+96]
    call get_f32
    test eax, eax
    jz .skip_sicken
    movss xmm0, [rsp+56]
    subss xmm0, [c_sick]
    mulss xmm0, [c_blackout]
    mulss xmm0, [g_dt]
    movss xmm1, [rsp+96]
    subss xmm1, xmm0
    xorps xmm2, xmm2
    maxss xmm1, xmm2
    movaps xmm0, xmm1
    mov rcx, [rsp+136]
    lea rdx, [field_consciousness]
    call set_f32
.skip_sicken:
    movss xmm0, [rsp+56]
    comiss xmm0, [c_poison]
    jb .done
    mov rcx, [rsp+136]
    lea rdx, [field_blood_oxygen]
    lea r8, [rsp+96]
    call get_f32
    test eax, eax
    jz .done
    movss xmm0, [rsp+56]
    subss xmm0, [c_poison]
    mulss xmm0, [c_hypoxia]
    mulss xmm0, [g_dt]
    movss xmm1, [rsp+96]
    subss xmm1, xmm0
    xorps xmm2, xmm2
    maxss xmm1, xmm2
    movaps xmm0, xmm1
    mov rcx, [rsp+136]
    lea rdx, [field_blood_oxygen]
    call set_f32
.done:
    add rsp, 184
    ret

rand01:
    mov eax, [g_rng]
    mov edx, eax
    shl eax, 13
    xor eax, edx
    mov edx, eax
    shr edx, 17
    xor eax, edx
    mov edx, eax
    shl edx, 5
    xor eax, edx
    mov [g_rng], eax
    and eax, 7fffffh
    or eax, 3f800000h
    movd xmm0, eax
    subss xmm0, [c_one]
    ret

str_eq:
    mov al, [rcx]
    cmp al, [rdx]
    jne .no
    test al, al
    je .yes
    inc rcx
    inc rdx
    jmp str_eq
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

make_f32:
    mov qword [rcx], 0
    mov qword [rcx+8], 0
    mov qword [rcx+16], 0
    mov qword [rcx+24], 0
    mov dword [rcx], UP_VAL_F32
    mov dword [rcx+4], 32
    movss [rcx+8], xmm0
    ret

make_i32:
    mov qword [rcx], 0
    mov qword [rcx+8], 0
    mov qword [rcx+16], 0
    mov qword [rcx+24], 0
    mov dword [rcx], UP_VAL_I32
    mov dword [rcx+4], 32
    mov [rcx+8], edx
    ret

host_log:
    sub rsp, 40
    mov r8, rdx
    mov edx, ecx
    mov rax, [g_host]
    mov rcx, [rax+8]
    call qword [rax+16]
    add rsp, 40
    ret

host_get_field:
    sub rsp, 40
    mov r9, r8
    mov r8, rdx
    mov rdx, rcx
    mov rax, [g_host]
    mov rcx, [rax+8]
    call qword [rax+184]
    add rsp, 40
    ret

host_set_field:
    sub rsp, 40
    mov r9, r8
    mov r8, rdx
    mov rdx, rcx
    mov rax, [g_host]
    mov rcx, [rax+8]
    call qword [rax+192]
    add rsp, 40
    ret

host_invoke:
    sub rsp, 56
    mov [rsp+32], r9
    mov [rsp+40], r10
    mov r9, r8
    mov r8, rdx
    mov rdx, rcx
    mov rax, [g_host]
    mov rcx, [rax+8]
    call qword [rax+176]
    add rsp, 56
    ret

host_retain:
    sub rsp, 40
    mov rdx, rcx
    mov rax, [g_host]
    mov rcx, [rax+8]
    call qword [rax+144]
    add rsp, 40
    ret

host_release:
    sub rsp, 40
    mov rdx, rcx
    mov rax, [g_host]
    mov rcx, [rax+8]
    call qword [rax+152]
    add rsp, 40
    ret

get_f32:
    sub rsp, 72
    mov [rsp+64], r8
    lea r8, [rsp+32]
    call host_get_field
    test eax, eax
    js .fail
    cmp dword [rsp+32], UP_VAL_F32
    jne .fail
    movss xmm0, [rsp+40]
    mov rax, [rsp+64]
    movss [rax], xmm0
    mov eax, 1
    add rsp, 72
    ret
.fail:
    xor eax, eax
    add rsp, 72
    ret

set_f32:
    sub rsp, 72
    lea r9, [rsp+32]
    mov qword [r9], 0
    mov qword [r9+8], 0
    mov qword [r9+16], 0
    mov qword [r9+24], 0
    mov dword [r9], UP_VAL_F32
    mov dword [r9+4], 32
    movss [r9+8], xmm0
    mov r8, r9
    call host_set_field
    add rsp, 72
    ret

section '.data' data readable writeable

g_host dq 0
g_dt dd 0.0
g_rng dd 254637891
g_hook_installed dd 0
g_hook_timer dd 0.0

body_states rb NUM_BODIES*BS_SIZE

c_hook_retry dd 1.0
c_strength dd 0.95
c_points_per_ml dd 0.25
c_extra_sickness dd 0.05
c_max_level dd 120.0
c_decay dd 0.03
c_tipsy dd 8.0
c_drunk dd 25.0
c_sick dd 50.0
c_poison dd 85.0
c_slowdown_per_level dd 0.004
c_max_slowdown dd 0.3
c_cheer dd 0.05
c_stumble dd 0.002
c_vomit_chance dd 0.002
c_blackout dd 0.1
c_hypoxia dd 0.1
c_one dd 1.0

module_description:
    dd 1
    dd 72
    dq module_id
    dq module_name
    dq module_version
    dq module_author
    dq module_text
    dq module_init
    dq module_tick
    dq module_shutdown

module_id db 'unknown-alcohol', 0
module_name db 'Unknown Alcohol', 0
module_version db '1.0.0', 0
module_author db 'Iakov Savelev', 0
module_text db 'Vanilla Alcohol is actually strong ethanol: per-body intoxication with decay, slowdown, stumbling, vomiting and hypoxia', 0

type_water_container db 'WaterContainerItem, Assembly-CSharp', 0
method_drink db 'Drink', 0
params_drink db 'Body,System.Single,System.String', 0
method_calculate_drain db 'CalculateDrain', 0
method_get_count db 'get_Count', 0
method_get_item db 'get_Item', 0
method_get_instance_id db 'GetInstanceID', 0
method_ragdoll db 'Ragdoll', 0
method_vomit db 'Vomit', 0

field_stack db 'stack', 0
field_liquid_id db 'liquidId', 0
field_stimulant db 'stimulantMultiplier', 0
field_happiness db 'happiness', 0
field_sickness db 'sicknessAmount', 0
field_consciousness db 'consciousness', 0
field_blood_oxygen db 'bloodOxygen', 0
field_vomiter db 'vomiter', 0

liquid_alcohol db 'alcohol', 0
msg_loaded db 'Unknown Alcohol loaded: vanilla alcohol is ethanol', 0
msg_unloaded db 'Unknown Alcohol unloaded', 0
msg_hook_ok db 'Unknown Alcohol: Drink hook installed', 0
msg_hook_failed db 'Unknown Alcohol: Drink hook failed', 0

section '.edata' export data readable
    export 'UnknownAlcohol.dll', UP_GetModule, 'UP_GetModule'

section '.reloc' fixups data readable discardable
    if $=$$
        dd 0, 8
    end if
