/*
 *  linux/arch/arm/boot/compressed/head.S
 *
 *  Copyright (C) 1996-2002 Russell King
 *  Copyright (C) 2004 Hyok S. Choi (MPU support)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */
/*SH 130904-1 START*/
#include <linux/linkage.h>
#include <asm/assembler.h>

	.arch	armv7-a
	/*SH 타깃 CPU가 armv7-a임을 나타냄*/
/*
 * Debugging stuff
 *
 * Note that these macros must not contain any code which is not
 * 100% relocatable.  Any attempt to do so will result in a crash.
 * Please select one of the following when turning on debugging.
 */
#ifdef DEBUG

#if defined(CONFIG_DEBUG_ICEDCC)

#if defined(CONFIG_CPU_V6) || defined(CONFIG_CPU_V6K) || defined(CONFIG_CPU_V7)
		/*SH 130904
		 * GNU ASM 매크로함수 정의 : 인자 사용시 '/'를 앞에 붙인다.
		 * .macro [함수이름], [인자1], [인자2], ..
		 * 명령어 /인자1
		 * 명령어 /인자2
		 * .endm
		 * */
		.macro	loadsp, rb, tmp
		.endm
		.macro	writeb, ch, rb
		mcr	p14, 0, \ch, c0, c5, 0
		.endm
#elif defined(CONFIG_CPU_XSCALE)
		.macro	loadsp, rb, tmp
		.endm
		.macro	writeb, ch, rb
		mcr	p14, 0, \ch, c8, c0, 0
		.endm
#else
		.macro	loadsp, rb, tmp
		.endm
		.macro	writeb, ch, rb
		mcr	p14, 0, \ch, c1, c0, 0
		.endm
#endif

#else

#include CONFIG_DEBUG_LL_INCLUDE

		.macro	writeb,	ch, rb
		senduart \ch, \rb
		.endm

#if defined(CONFIG_ARCH_SA1100)
		.macro	loadsp, rb, tmp
		mov	\rb, #0x80000000	@ physical base address
#ifdef CONFIG_DEBUG_LL_SER3
		add	\rb, \rb, #0x00050000	@ Ser3
#else
		add	\rb, \rb, #0x00010000	@ Ser1
#endif
		.endm
#elif defined(CONFIG_ARCH_S3C24XX)
		.macro loadsp, rb, tmp
		mov	\rb, #0x50000000
		add	\rb, \rb, #0x4000 * CONFIG_S3C_LOWLEVEL_UART_PORT
		.endm
#else
		.macro	loadsp,	rb, tmp
		addruart \rb, \tmp
		.endm
#endif
#endif
#endif

		.macro	kputc,val
		mov	r0, \val
		bl	putc
		.endm

		.macro	kphex,val,len
		mov	r0, \val
		mov	r1, #\len
		bl	phex
		.endm

		.macro	debug_reloc_start
#ifdef DEBUG
		kputc	#'\n'
		kphex	r6, 8		/* processor id */
		kputc	#':'
		kphex	r7, 8		/* architecture id */
#ifdef CONFIG_CPU_CP15
		kputc	#':'
		mrc	p15, 0, r0, c1, c0
		kphex	r0, 8		/* control reg */
#endif
		kputc	#'\n'
		kphex	r5, 8		/* decompressed kernel start */
		kputc	#'-'
		kphex	r9, 8		/* decompressed kernel end  */
		kputc	#'>'
		kphex	r4, 8		/* kernel execution address */
		kputc	#'\n'
#endif
		.endm

		.macro	debug_reloc_end
#ifdef DEBUG
		kphex	r5, 8		/* end of kernel */
		kputc	#'\n'
		mov	r0, r4
		bl	memdump		/* dump 256 bytes at start of kernel */
#endif
		.endm

/*SH 130904
 * 부트로더로 부터 초기 넘어오는 레지스터 값들
 * 참조 : Vincent Sanders, Booting ARM Linux
 * r0 = Must be 0
 * r1 = ARM Linux Machine type = architecture ID
 * r2 = The Physical address of the parameter list
 * */
/*SH 130904
 * zImage 관련 정보 - 이건 zImage를 이렇게 만들어야 된다는 우리들만의 약속~
 * zImage start + 0x24 = Magic number(0x016f2818)
 * zImage start + 0x28 = abs zImage start address(start)
 * zImage start + 0x2c = abs zImage end address(_edata)
 * */
/*SH 130904
 * arch/arm/boot/compressed/vmlinux.lds 에 의하여 아래 .section ".start"가 '*(.start)'이므로 커널의 시작점이 된다.
 * */
		.section ".start", #alloc, #execinstr	/*SH .section "섹션이름", 속성1, 속성2 : GNU LD에서 링크스크립터파일에서 사용하는 섹션 식별자 정의*/
							/*SH #alloc : 할당가능, #execinstr : 실행가능*/
							/*SH 여기서는 arch/arm/boot/compressed/vmlinux.lds 의 '*(.start)'가 .section ".start"임*/
/*
 * sort out different calling conventions
 */
		.align				/*SH .align : 다음에 올 코드의 정렬 간격을 나타냄. 기본값 2*/
						/*SH ex>.align 3 : arm에서는 2^3 = 8 byte 간격으로 정렬*/
						/*SH               i386에서는 걍 3 byte 간격으로 정렬*/
		.arm				@ Always enter in ARM state
start:
		.type	start,#function
		.rept	7			/*SH .rept # : .endr을 만나기 전까지의 명령어를 #번 반복하여 어셈블함*/
						/*SH 실제 코드의 시작*/
		mov	r0, r0
		.endr
   ARM(		mov	r0, r0		)	/*SH 여기 까지 mov r0, r0를 반복하는 무의미한 코드이다.*/
   ARM(		b	1f		)	/*SH 라벨 '1'(f:앞으로 주소값, b:이미 지나온 주소값) 으로 분기*/
 THUMB(		adr	r12, BSYM(1f)	)
 THUMB(		bx	r12		)
/*SH 130904
 * ARM(), THUMB()
 * arch/arm/include/asm/unified.h 에서 커널 설정 CONFIG_THUMB2_KERNEL 의 설정 유무에 의하여,
 * y : THUMB() 부분의 코드가 남는다.
 * n : ARM() 부분의 코드가 남는다. -> 여기서는 'n'
 * */
		.word	0x016f2818		@ Magic numbers to help the loader
		.word	start			@ absolute load/run zImage address
		.word	_edata			@ zImage end address
 THUMB(		.thumb			)
1:
		mrs	r9, cpsr		/*SH r9 = cpsr*/
/*SH 130904
 * ARMv7 Format of the CPSR and SPSRs - 출처 : A.R.M B1.3.3 Program Status Registers(PSRs)
 * 
 *
 * |31|30|29|28|27|26 25|24|23       20|19       16|15             10|09|08|07|06|05|04          00|
 * |-----------------------------------------------------------------------------------------------|
 * |  |  |  |  |  |     |  |           |           |                 |  |  |  |  |  |              |
 * | N| Z| C| V| Q|     | J|   Reserved|    GE[3:0]|          IT[7:2]| E| A| I| F| T|        M[4:0]|
 * |  |  |  |  |  |     |  |           |           |                 |  |  |  |  |  |              |
 * |-----------------------------------------------------------------------------------------------|
 * |31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10|09|08|07|06|05|04|03|02|01|00|
 *
 * N: 계산의 결과가 음수일 때 1로 체크된다.
 * Z: 계산의 결과가 0일 때 1로 체크된다.
 * C: 계산 결과에 캐리가 발생하거나, 나눗셈할 때 자리 빌림이 발생하면 1로 체크된다.
 * V: 계산 결과에 오버플로우가 발생하면 1로 체크된다.
 * Q: 곱셈을 계산할 때 32비트를 넘어가는 올림수에 이용한다.
 * J: Cortex-A 이상 프로세서에서 Jazelle 상태로 변경시 1로 체크된다.
 * GE: SIMD(Single Instruction Multiple Data: 하나의 명령으로 여러 개의 데이터를 동시에 처리) 명령을 사용해서 연산을 할 때 하프워드 단위로 크거나 같은지를 표시하는 비트
 * IT: ITSTATE로 Thumb-2에 포함된 IT(If-then) 명령어를 위한 필드이다. 원래 Thumb 명령어는 conditional execution이 안되는데 이 명령어와 IT Field로 conditional execution을 할 수 있도록 만든 것이다.
 * E: 데이터의 엔디언을 표시하는 비트
 * A: 예측가능한 data abort만 발생하도록 체크, 이 비트를 끄면 예측 불가능한 asynchronous data abort의 발생을 허용한다.
 * I: 이 비트가 켜져 있으면 IRQ 비활성화
 * F: 이 비트가 켜져 있으면 FIQ 비활성화
 * T: Thumb 상태일 때 1로 체크
 * M: 모드 비트, 각 동작 모드 별로 모드 비트의 값은 아래와 같다.
 * 10000: User
 * 10001: FIQ
 * 10010: IRQ
 * 10011: Supervisor
 * 10111: Abort
 * 11010: Hyp
 * 11011: Undefined
 * 11111: System
 *
 * GNU AS PSR 접미사 사용 의미 : cpsr_cxsf, spsr_cxsf 이런 식으로 사용
 * f : 플래그 필드 마스크 바이트 : [31:24] -> N, Z, C, V, Q, J
 * s : 상태 필드 마스크 바이트 : [23:16] -> GE
 * x : 확장 필드 마스크 바이트 : [15:8] -> IT, E, A
 * c : 제어 필드 마스크 바이트 : [7:0] -> I, F, T, M
 * */
/*SH 130904-1 END*/
/*SH 130904-2 START*/
#ifdef CONFIG_ARM_VIRT_EXT	/*SH Y*/
		/*SH FIXME : 가상화 지원과 관련한 코드*/
		bl	__hyp_stub_install	@ get into SVC mode, reversibly	/*SH bl : lr(r14) 에 다음 명령어 주소값을 저장 후 분기*/
#endif
		mov	r7, r1			@ save architecture ID
		mov	r8, r2			@ save atags pointer

		/*
		 * Booting from Angel - need to enter SVC mode and disable
		 * FIQs/IRQs (numeric definitions from angel arm.h source).
		 * We only do this if we were in user mode on entry.
		 */
		mrs	r2, cpsr		@ get current mode
		tst	r2, #3			@ not user?	/*SH tst : r2 AND 3 에서 CPSR 플래그 업데이트*/
								/*SH tst 연산결과 0이면 CPSR의 Z = 1 -> 이것은 현재 모드가 user 모드임을 나타냄*/
		bne	not_angel		/*SH ne : 조건필드 같지 않음 : CPSR의 Z 비트가 0이면 ture, 1이면 false*/
						/*SH 현재 모드가 user 이면 ne조건 필드가 false가 되어 계속진행, user 가 아니라면 true가 되어 not_angel로 분기*/
		mov	r0, #0x17		@ angel_SWIreason_EnterSVC
 ARM(		swi	0x123456	)	@ angel_SWI_ARM	/*SH FIXME : swi 를 발생하여 Supervisor 모드로 전환하는 듯 하지만 원리를 모르겠음 */
 THUMB(		svc	0xab		)	@ angel_SWI_THUMB
not_angel:
/*SH 130904-2 END*/
/*SH 130905-1 START*/
		safe_svcmode_maskall r0		/*SH arch/arm/include/asm/assembler.h의 safe_svcmode_maskall*/
		msr	spsr_cxsf, r9		@ Save the CPU boot mode in	/*SH r9 = 부팅 당시 cpsr*/
						@ SPSR
		/*
		 * Note that some cache flushing and other stuff may
		 * be needed here - is there an Angel SWI call for this?
		 */

		/*
		 * some architecture specific code can be inserted
		 * by the linker here, but it should preserve r7, r8, and r9.
		 */

		.text				/*SH .text 섹션의 시작*/

#ifdef CONFIG_AUTO_ZRELADDR	/*SH Y*/
		@ determine final kernel image address
		mov	r4, pc			/*SH r4 = pc*/
		and	r4, r4, #0xf8000000	/*SH 하위 주소 클리어*/
		add	r4, r4, #TEXT_OFFSET	/*SH TEXT_OFFSET : arch/arm/boot/compressed/.head.o.cmd에 -DTEXT_OFFSET=0x00008000으로 정의*/
						/*SH r4 = 0xXX008000 : XX는 현재 수행되고 있는 주소값임을 유의해야함*/
						/*SH r4(0xXX008000)은 커널 압축 해제 시작점이 된다.*/
						/*SH cache_on이 되는 조건이 되면 r4는 cache에 사용할 page_table 마지막 주소값이 된다.*/
#else
		ldr	r4, =zreladdr
#endif

		/*
		 * Set up a page table only if it won't overwrite ourself.
		 * That means r4 < pc && r4 - 16k page directory > &_end.
		 * SH 주석 이거 위에 '&&'가 '||'로 바뀌어야 할꺼 같은데... 아놔! 이 주석때문에 두시간 헤맷음!!
		 * Given that r4 > &_end is most unfrequent, we add a rough
		 * additional 1MB of room for a possible appended DTB.
		 */
		mov	r0, pc			/*SH r0 = pc*/
		cmp	r0, r4			/*SH cmp : r0 - r4에서 cpcr 플래그 업데이트*/
		ldrcc	r0, LC0+32		/*SH cc 조건 필드 : 보다 작음 : FIXME PSR의 어떤 필드를 보고 판단하는지? N,C비트 유력*/
						/*SH r0 작으면 r0 = *(LC0 + 32) : 라벨 'LC0' + 32 에 있는 데이터 로드*/
						/*SH _end - restart + 16384 + 1024*1024 : restart부터 zImage끝까지 크기 + 16k(page directory) + 1M(room for a DTB)*/
		addcc	r0, r0, pc		/*SH r0 작으면 r0 += PC : r4가 실행중 기준으로 값이 되어 있으므로 비교위해 실행중 주소를 구하는 느낌?*/
		cmpcc	r4, r0			/*SH r0 작으면 r4 - r0 에서 cpcr 플래그 업데이트*/
		orrcc	r4, r4, #1		@ remember we skipped cache_on	/*SH r4 작으면 r4 |= 1 : 기억!! 이 명령어가 수행되는 조건은 cache_on을 하지 않는다!*/
		blcs	cache_on		/*SH 첫번째 cmp에서 r0가 크거나, 두번째 cmpcc에서 r4가 크면 lr=다음명령어 수행 후 cache_on으로 분기한다.*/
		/*SH 130905
		 * 압축된 커널의 압축 해제 코드를 수행 하는데 캐시를 사용할 수 있는 조건을 검사 후, 만족하면 cache_on한다.
		 * 조건 : 캐시에서 사용될 page table을 셋팅하는데 현재 코드를 overwrite 하지 않으면 만사 ok! 그것은 다음 두 조건으로 검사된다.
		 *        1. pc가 page table 셋팅 마지막주소값 보다 크거나,
		 *        2. page table 셋팅 시작점 주소값이 로드된 zImage 마지막 주소 + page table크기 + DTB를 위한 주소공간 크기(1MB) 보다 클경우
		 *        page table이 셋팅가능하여 cache_on 진입!
		 * */

/*SH 130905-2 END*/
/*SH 130909-1 START*/
restart:	adr	r0, LC0
		ldmia	r0, {r1, r2, r3, r6, r10, r11, r12}
		ldr	sp, [r0, #28]
		/*SH 130909
		 * r0  = 라벨 'LC0' Running time의 실행 주소값
		 * r1  = 라벨 'LC0'의 절대 주소값
		 * r2  = __bss_start
		 * r3  = _end : bss영역 끝
		 * r6  = _edata : zImage 코드 끝(bss, stack 영역 미포함) 
		 * r10 = input_data_end - 4(inflated size location) : arch/arm/boot/compressed/vmlinux.lds의 .piggydata -> arch/arm/boot/compressed/piggy.gzip.S에서 위치를 알수 있다. 압축해제한코드 사이즈 저장해 둔 곳
		 * r11 = _got_start
		 * r12(ip) = _got_end
		 * r13(sp) = L_user_stack_end : arch/arm/boot/compressed/vmlinux.lds의 .stack 영역의 끝으로 zImage 코드의 끝(bss, stack 모두 포함)
		 * */

		/*
		 * We might be running at a different address.  We need
		 * to fix up various pointers.
		 */
		sub	r0, r0, r1		@ calculate the delta offset	/*SH 절대 주소와 Running 주소의 Delta offset 구함*/
		add	r6, r6, r0		@ _edata			/*SH _edata 주소 Running 주소로 보정*/
		add	r10, r10, r0		@ inflated kernel size location	/*SH 압축 해제 코드 크기 주소 Running 주소로 보정*/
/*SH 130909-1 END*/
/*SH 130910-1 START*/

		/*
		 * The kernel build system appends the size of the
		 * decompressed kernel at the end of the compressed data
		 * in little-endian form.
		 */
		ldrb	r9, [r10, #0]
		ldrb	lr, [r10, #1]
		orr	r9, r9, lr, lsl #8
		ldrb	lr, [r10, #2]
		ldrb	r10, [r10, #3]
		orr	r9, r9, lr, lsl #16
		orr	r9, r9, r10, lsl #24

#ifndef CONFIG_ZBOOT_ROM	/*SH N*/
		/* malloc space is above the relocated stack (64k max) */
		add	sp, sp, r0		/*SH sp 주소 Running 주소로 보정*/
		add	r10, sp, #0x10000	/*SH r10 = sp(zImage 코드의 끝) + 16k : 후에 sp를 16k 더 사용하기위해 +16k하는 것임*/
#else
		/*
		 * With ZBOOT_ROM the bss/stack is non relocatable,
		 * but someone could still run this code from RAM,
		 * in which case our reference is _edata.
		 */
		mov	r10, r6
#endif

		mov	r5, #0			@ init dtb size to 0
#ifdef CONFIG_ARM_APPENDED_DTB	/*SH Y*/
/*
 *   r0  = delta
 *   r2  = BSS start
 *   r3  = BSS end
 *   r4  = final kernel address (possibly with LSB set)
 *   r5  = appended dtb size (still unknown)
 *   r6  = _edata
 *   r7  = architecture ID
 *   r8  = atags/device tree pointer
 *   r9  = size of decompressed image
 *   r10 = end of this image, including  bss/stack/malloc space if non XIP
 *   r11 = GOT start
 *   r12 = GOT end
 *   sp  = stack pointer
 *
 * if there are device trees (dtb) appended to zImage, advance r10 so that the
 * dtb data will get relocated along with the kernel if necessary.
 */

		ldr	lr, [r6, #0]
#ifndef __ARMEB__	/*SH N*/
		ldr	r1, =0xedfe0dd0		@ sig is 0xd00dfeed big endian
#else
		ldr	r1, =0xd00dfeed
#endif
		cmp	lr, r1			/*SH dtb가 구성 되어 있다면 구성후 첫번째 식별자로 0xd00dfeed를 넣어놓는다.*/
		bne	dtb_check_done		@ not found

#ifdef CONFIG_ARM_ATAG_DTB_COMPAT	/*SH Y*/
		/*
		 * OK... Let's do some funky business here.
		 * If we do have a DTB appended to zImage, and we do have
		 * an ATAG list around, we want the later to be translated
		 * and folded into the former here.  To be on the safe side,
		 * let's temporarily move  the stack away into the malloc
		 * area.  No GOT fixup has occurred yet, but none of the
		 * code we're about to call uses any global variable.
		*/
		add	sp, sp, #0x10000	/*SH 현재 sp에서 64k(0x10000)를 더 할당 해줌*/
		stmfd	sp!, {r0-r3, ip, lr}	/*SH r0, r1, r2, r3, r12(ip), r14(lr) 백업*/
		mov	r0, r8
		mov	r1, r6
		sub	r2, sp, r6		/*SH _edata ~ sp 까지의 크기 구함 = 버퍼크기*/
		bl	atags_to_fdt		/*SH 부트로더에서 넘겨받은 atag/dtb 포인터로 부터 파싱해 _edata 부터 fdt로 만들어 저장한다.*/
						/*SH 성공하면 r0 = 0, 실패시 r0 = 1*/

		/*
		 * If returned value is 1, there is no ATAG at the location
		 * pointed by r8.  Try the typical 0x100 offset from start
		 * of RAM and hope for the best.
		 */
		/*SH 위 코드에서 atags_to_fdt 가 실패시 TEXT_OFFSET + 0x100에서 다시 찾아본다.*/
		/*SH 그 이유는 TEXT_OFFSET + 0x100에 dtb를 두는것이 통상적인 관행이기 때문이다.*/
		cmp	r0, #1
		sub	r0, r4, #TEXT_OFFSET
		bic	r0, r0, #1
		add	r0, r0, #0x100
		mov	r1, r6
		sub	r2, sp, r6
		bleq	atags_to_fdt

		ldmfd	sp!, {r0-r3, ip, lr}	/*SH r0, r1, r2, r3, r12(ip), r14(lr) 복원*/
		sub	sp, sp, #0x10000	/*SH sp 크기도 - 64k(0x10000)로 복원*/
#endif

		mov	r8, r6			@ use the appended device tree	/*SH 실제 커널에서 사용할 fdt를 r8에 할당*/

		/*
		 * Make sure that the DTB doesn't end up in the final
		 * kernel's .bss area. To do so, we adjust the decompressed
		 * kernel size to compensate if that .bss size is larger
		 * than the relocated code.
		 */
		/*SH 130911
		 * DTB가 압축을 해제한 코드의 BSS영역을 침범하지 않도록, 검사 후 압축해제코드 사이즈를 보정해준다.
		 * */
		ldr	r5, =_kernel_bss_size	/*SH arch/arm/boot/compressed/.vmlinux.cmd에 --defsym _kernel_bss_size=269856*/
		adr	r1, wont_overwrite
		sub	r1, r6, r1	/*SH wont_overwrite ~ _edata 코드 사이즈*/
		subs	r1, r5, r1	/*SH _kernel_bss_size - (wont_overwrite ~ _edata 코드 사이즈)*/
		addhi	r9, r9, r1	/*SH _kernel_bss_size - (wont_overwrite ~ _edata 코드 사이즈) 가 양수라면 그 값을 압축해제코드사이즈와 더해준다.*/

		/* Get the dtb's size */
		ldr	r5, [r6, #4]	/*SH r5 = DTB 크기*/
#ifndef __ARMEB__	/*SH Y*/
		/* convert r5 (dtb size) to little endian */
		eor	r1, r5, r5, ror #16
		bic	r1, r1, #0x00ff0000
		mov	r5, r5, ror #8
		eor	r5, r5, r1, lsr #8
#endif

		/* preserve 64-bit alignment */
		add	r5, r5, #7
		bic	r5, r5, #7

		/* relocate some pointers past the appended dtb */
		add	r6, r6, r5	/*SH _edata += DTB Size*/
		add	r10, r10, r5	/*SH bss/stack/malloc 포함 한 현재 코드 끝 += DTB Size*/
		add	sp, sp, r5	/*SH sp += DTB Size*/
dtb_check_done:
#endif

/*
 * Check to see if we will overwrite ourselves.
 *   r4  = final kernel address (possibly with LSB set)
 *   r9  = size of decompressed image
 *   r10 = end of this image, including  bss/stack/malloc space if non XIP
 * We basically want:
 *   r4 - 16k page directory >= r10 -> OK
 *   r4 + image length <= address of wont_overwrite -> OK
 * Note: the possible LSB in r4 is harmless here.
 */
/*SH 130911
 * 1. r4 - 16k page directory >= r10 -> OK
 * |     |상위 주소
 * |     |
 * |-----|<- 압축해제 커널 로드 주소(r4)
 * |-----|<- page directory 시작 주소(크기16k) 즉, 이 곳이 r4 - 16k page directory
 * |     |
 * |-----|<- 현재 압축된 커널(zImage)코드 끝(r10)
 * |     |
 * |     |하위 주소
 *
 * 2. r4 + image length <= address of wont_overwrite -> OK
 * |     |상위 주소
 * |     |
 * |-----|<- wont_overwrite(r9)
 * |     |
 * |-----|<- 압축해제한 커널의 마지막 주소(r10)
 * |     |
 * |     |
 * |     |하위 주소
 * */
		add	r10, r10, #16384	/*SH 주석에는 r4(커널 로드 주소) - 16k라고 하고 사실은 r10(현재 압축된 커널코드 끝) + 16k를 해서 r4와 비교한다.*/
		cmp	r4, r10			/*SH 1번 체크*/
		bhs	wont_overwrite
		add	r10, r4, r9		/*SH r10 = 압축해제 커널 로드 주소 + 압축해제 코드 사이즈 = 실제 압축해제 커널의 마지막 주소*/
		adr	r9, wont_overwrite
		cmp	r10, r9			/*SH 2번 체크*/
		bls	wont_overwrite
/*SH 130910-1 END*/
/*SH 130916-1 START*/


/*
 * Relocate ourselves past the end of the decompressed kernel.
 *   r6  = _edata
 *   r10 = end of the decompressed kernel
 * Because we always copy ahead, we need to do it from the end and go
 * backward in case the source and destination overlap.
 */
/*SH 130916
 * Code relocate : 'X' 로 표시
 * |     |상위 주소
 * |-----|<- relocate된 _edata(r9)
 * |XXXXX|
 * |XXXXX|
 * |XXXXX|
 * |-----|<- relocate된 라벨 'restart'주소
 * |-----|<- 압축해제한 커널의 마지막 주소(r10)
 * |     |
 * |     |
 * |     |하위 주소
 *
 * 압축해제한 커널의 마지막 주소로 부터 r9만큼 떨어진 곳에 현재 코드의 _edata 부터 현재 코드의 restart라벨의 주소값 까지 복사
 * */
		/*
		 * Bump to the next 256-byte boundary with the size of
		 * the relocation code added. This avoids overwriting
		 * ourself when the offset is small.
		 */
		add	r10, r10, #((reloc_code_end - restart + 256) & ~255)	/*SH 커널 압축 해제의 끝(r10) + (( restart ~ reloc_code_end까지의 크기 + 256 byte 주소) & 256 byte align  ))*/
		bic	r10, r10, #255						/*SH r0에 대한 256 byte align*/

		/* Get start of code we want to copy and align it down. */
		adr	r5, restart
		bic	r5, r5, #31	/*SH restart(r5)주소에 대한 32byte align*/

/* Relocate the hyp vector base if necessary */
#ifdef CONFIG_ARM_VIRT_EXT	/*SH Y*/
		mrs	r0, spsr
		and	r0, r0, #MODE_MASK
		cmp	r0, #HYP_MODE
		bne	1f
		/*SH 현재 모드가 하이퍼바이저 모드가 아니면 라벨'1'로 분기*/

		/*SH FIXME 하이퍼바이저 모드라면, __hyp_get_vectors, __hyp_set_vectors 를 이용하여 재배치(relocate)할 주소와 관련한 뭔가 연산을 하는듯함*/
		bl	__hyp_get_vectors
		sub	r0, r0, r5
		add	r0, r0, r10
		bl	__hyp_set_vectors
1:
#endif

		sub	r9, r6, r5		@ size to copy		/*SH r9 = restart ~ _edata까지 코드 크기*/
		add	r9, r9, #31		@ rounded up to a multiple
		bic	r9, r9, #31		@ ... of 32 bytes	/*SH 32 byte align*/
		add	r6, r9, r5		/*SH r6 = restart ~ _edata 코드크기(r9) + restart 주소값(r5) = 실제 _edata의 주소값*/
		add	r9, r9, r10		/*SH r9 = restart ~ _edata 코드크기(r9) + 커널 압축 해제의 끝(r10) = relocate 할 주소값(압축해제할 코드의 뒷부분으로 보냄)*/

1:		ldmdb	r6!, {r0 - r3, r10 - r12, lr}
		cmp	r6, r5
		stmdb	r9!, {r0 - r3, r10 - r12, lr}
		bhi	1b

		/* Preserve offset to relocated code. */
		sub	r6, r9, r6	/*SH 위 루프 결과 r6 = restart라벨의 주소값 , r9는 relocate된 restart라벨의 주소값*/
					/*SH r6 = relocate된 restart - 현재 restart = relocate에 대한 offset값 구함*/

#ifndef CONFIG_ZBOOT_ROM	/*SH N*/
		/* cache_clean_flush may use the stack, so relocate it */
		add	sp, sp, r6		/*SH relocate sp 주소값 보정*/
#endif

		tst	r4, #1
		bleq	cache_clean_flush

		adr	r0, BSYM(restart)	/*SH relocate된 restart 주소값 보정 후 relocate된 restart로 분기*/
		add	r0, r0, r6
		mov	pc, r0
/*SH 130916-1 END*/

/*SH 131029-1 START*/
wont_overwrite:
/*
 * If delta is zero, we are running at the address we were linked at.
 *   r0  = delta
 *   r2  = BSS start
 *   r3  = BSS end
 *   r4  = kernel execution address (possibly with LSB set)
 *   r5  = appended dtb size (0 if not present)
 *   r7  = architecture ID
 *   r8  = atags pointer
 *   r11 = GOT start
 *   r12 = GOT end
 *   sp  = stack pointer
 */
		orrs	r1, r0, r5
		beq	not_relocated

		add	r11, r11, r0
		add	r12, r12, r0

#ifndef CONFIG_ZBOOT_ROM	/*SH N*/
		/*
		 * If we're running fully PIC === CONFIG_ZBOOT_ROM = n,
		 * we need to fix up pointers into the BSS region.
		 * Note that the stack pointer has already been fixed up.
		 */
		add	r2, r2, r0
		add	r3, r3, r0

		/*
		 * Relocate all entries in the GOT table.
		 * Bump bss entries to _edata + dtb size
		 */
1:		ldr	r1, [r11, #0]		@ relocate entries in the GOT
		add	r1, r1, r0		@ This fixes up C references
		cmp	r1, r2			@ if entry >= bss_start &&
		cmphs	r3, r1			@       bss_end > entry
		addhi	r1, r1, r5		@    entry += dtb size
		str	r1, [r11], #4		@ next entry
		cmp	r11, r12
		blo	1b

		/* bump our bss pointers too */
		add	r2, r2, r5
		add	r3, r3, r5

#else

		/*
		 * Relocate entries in the GOT table.  We only relocate
		 * the entries that are outside the (relocated) BSS region.
		 */
1:		ldr	r1, [r11, #0]		@ relocate entries in the GOT
		cmp	r1, r2			@ entry < bss_start ||
		cmphs	r3, r1			@ _end < entry
		addlo	r1, r1, r0		@ table.  This fixes up the
		str	r1, [r11], #4		@ C references.
		cmp	r11, r12
		blo	1b
#endif

not_relocated:	mov	r0, #0
1:		str	r0, [r2], #4		@ clear bss
		str	r0, [r2], #4
		str	r0, [r2], #4
		str	r0, [r2], #4
		cmp	r2, r3
		blo	1b

		/*
		 * Did we skip the cache setup earlier?
		 * That is indicated by the LSB in r4.
		 * Do it now if so.
		 */
		tst	r4, #1
		bic	r4, r4, #1
		blne	cache_on

/*
 * The C runtime environment should now be setup sufficiently.
 * Set up some pointers, and start decompressing.
 *   r4  = kernel execution address
 *   r7  = architecture ID
 *   r8  = atags pointer
 */
		mov	r0, r4
		mov	r1, sp			@ malloc space above stack
		add	r2, sp, #0x10000	@ 64k max
		mov	r3, r7
		bl	decompress_kernel
		bl	cache_clean_flush
		bl	cache_off
		mov	r1, r7			@ restore architecture number
		mov	r2, r8			@ restore atags pointer

#ifdef CONFIG_ARM_VIRT_EXT
		mrs	r0, spsr		@ Get saved CPU boot mode
		and	r0, r0, #MODE_MASK
		cmp	r0, #HYP_MODE		@ if not booted in HYP mode...
		bne	__enter_kernel		@ boot kernel directly

		adr	r12, .L__hyp_reentry_vectors_offset
		ldr	r0, [r12]
		add	r0, r0, r12

		bl	__hyp_set_vectors
		__HVC(0)			@ otherwise bounce to hyp mode

		b	.			@ should never be reached

		.align	2
.L__hyp_reentry_vectors_offset:	.long	__hyp_reentry_vectors - .
#else
		b	__enter_kernel
/*SH 131029-1 END */
#endif

		.align	2
		.type	LC0, #object
LC0:		.word	LC0			@ r1	/*SH LC0의 절대 주소값*/
		.word	__bss_start		@ r2
		.word	_end			@ r3	/*SH bss영역 끝*/
		.word	_edata			@ r6	/*SH zImage코드 끝(bss, stack 영역 미포함)*/
		.word	input_data_end - 4	@ r10 (inflated size location)	/*SH 압축해제된코드 사이즈 저장해둔 곳*/
		.word	_got_start		@ r11
		.word	_got_end		@ ip
		.word	.L_user_stack_end	@ sp	/*SH 스택의 끝(zImage의 끝을 나타낸다. bss, stack 영역 모두 포함) */
		.word	_end - restart + 16384 + 1024*1024
		.size	LC0, . - LC0

#ifdef CONFIG_ARCH_RPC
		.globl	params
params:		ldr	r0, =0x10000100		@ params_phys for RPC
		mov	pc, lr
		.ltorg
		.align
#endif

/*
 * Turn on the cache.  We need to setup some page tables so that we
 * can have both the I and D caches on.
 *
 * We place the page tables 16k down from the kernel execution address,
 * and we hope that nothing else is using it.  If we're using it, we
 * will go pop!
 *
 * On entry,
 *  r4 = kernel execution address
 *  r7 = architecture number
 *  r8 = atags pointer
 * On exit,
 *  r0, r1, r2, r3, r9, r10, r12 corrupted
 * This routine must preserve:
 *  r4, r7, r8
 */
		.align	5
cache_on:	mov	r3, #8			@ cache_on function
		b	call_cache_fn

/*
 * Initialize the highest priority protection region, PR7
 * to cover all 32bit address and cacheable and bufferable.
 */
__armv4_mpu_cache_on:
		mov	r0, #0x3f		@ 4G, the whole
		mcr	p15, 0, r0, c6, c7, 0	@ PR7 Area Setting
		mcr 	p15, 0, r0, c6, c7, 1

		mov	r0, #0x80		@ PR7
		mcr	p15, 0, r0, c2, c0, 0	@ D-cache on
		mcr	p15, 0, r0, c2, c0, 1	@ I-cache on
		mcr	p15, 0, r0, c3, c0, 0	@ write-buffer on

		mov	r0, #0xc000
		mcr	p15, 0, r0, c5, c0, 1	@ I-access permission
		mcr	p15, 0, r0, c5, c0, 0	@ D-access permission

		mov	r0, #0
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer
		mcr	p15, 0, r0, c7, c5, 0	@ flush(inval) I-Cache
		mcr	p15, 0, r0, c7, c6, 0	@ flush(inval) D-Cache
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg
						@ ...I .... ..D. WC.M
		orr	r0, r0, #0x002d		@ .... .... ..1. 11.1
		orr	r0, r0, #0x1000		@ ...1 .... .... ....

		mcr	p15, 0, r0, c1, c0, 0	@ write control reg

		mov	r0, #0
		mcr	p15, 0, r0, c7, c5, 0	@ flush(inval) I-Cache
		mcr	p15, 0, r0, c7, c6, 0	@ flush(inval) D-Cache
		mov	pc, lr

__armv3_mpu_cache_on:
		mov	r0, #0x3f		@ 4G, the whole
		mcr	p15, 0, r0, c6, c7, 0	@ PR7 Area Setting

		mov	r0, #0x80		@ PR7
		mcr	p15, 0, r0, c2, c0, 0	@ cache on
		mcr	p15, 0, r0, c3, c0, 0	@ write-buffer on

		mov	r0, #0xc000
		mcr	p15, 0, r0, c5, c0, 0	@ access permission

		mov	r0, #0
		mcr	p15, 0, r0, c7, c0, 0	@ invalidate whole cache v3
		/*
		 * ?? ARMv3 MMU does not allow reading the control register,
		 * does this really work on ARMv3 MPU?
		 */
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg
						@ .... .... .... WC.M
		orr	r0, r0, #0x000d		@ .... .... .... 11.1
		/* ?? this overwrites the value constructed above? */
		mov	r0, #0
		mcr	p15, 0, r0, c1, c0, 0	@ write control reg

		/* ?? invalidate for the second time? */
		mcr	p15, 0, r0, c7, c0, 0	@ invalidate whole cache v3
		mov	pc, lr

#ifdef CONFIG_CPU_DCACHE_WRITETHROUGH	/*SH N*/
#define CB_BITS 0x08
#else
#define CB_BITS 0x0c	/*SH this*/
#endif

/*SH 130905
 * __setup_mmu : 0xXX004000~0xXX008000 영역에 page directory를 구성한다. page table은 Section format으로 셋팅된다.
 * 초기값
 * r4 = 0xXX008000 : 압축해제 커널 시작점(page directory의 끝점)
 * r6 = #CB_BITS | 0x02
 *
 * r1 은 page table에 저장될 Section format로 사용된다.
 *
 * */
/*SH 130905-1 END*/
/*SH 130905-2 START*/
__setup_mmu:	sub	r3, r4, #16384		@ Page directory size	/*SH r3 = page directory 시작점*/
		bic	r3, r3, #0xff		@ Align the pointer	/*SH 하위 주소값 Align*/
		bic	r3, r3, #0x3f00
/*
 * Initialise the page tables, turning on the cacheable and bufferable
 * bits for the RAM area only.
 */
/*SH END 130724-2*/
/*SH START 130725-1*/
/*SH 130905
 * 밑의 루프에서 r1의 값이 page directory에 저장될 page table의 값이다.
 * Section으로 셋팅하고 format은 아래와 같다.
 * A.R.M B3.5.1 Short-descriptor translation table format descriptors
 * Section format
 * |31:30:29:28|27:26:25:24|23:22:21:20|19:18:17:16|15:14:13:12|11:10:09:08|07:06:05:04|03:02:01:00|
 * |                                   |  |  |  |  |  |        |     |  |           |  |  |  |  |  |
 * | Section base address              |NS| 0|nG| S|AP|   TEX  |  AP |xx|   Domain  |XN| C| B| 1| 0|
 * |                                   |  |  |  |  |  |        |     |  |           |  |  |  |  |  |
 * | 8: 4: 2: 0| 8: 4: 2: 0| 8: 4: 2: 0| 8: 4: 2: 0| 8: 4: 2: 0| 8: 4: 2: 0| 8: 4: 2: 0| 8: 4: 2: 0|
 *
 * NS : Non-secure
 * nG : The not global bit
 * S : The Shareable bit
 * AP[15], AP[11:10] : Access Permissions bits
 * TEX[14:12] : Memory region attribute bits
 * Domain[8:5] : Domain field
 * XN : The Execute-never bit
 * C : Cacheable
 * B : Bufferable
 * */
		mov	r0, r3
		mov	r9, r0, lsr #18
		mov	r9, r9, lsl #18		@ start of RAM		/*SH r3 = RAM의 시작 주소값 : r3의 하위 18비트를 0으로 클리어 하여 RAM의 시작점을 구한다.*/
		add	r10, r9, #0x10000000	@ a reasonable RAM size	/*SH r10 = RAM의 끝 주소값 : 넉넉히 사이즈를 계산해준다. 여기서는 256MB */
		mov	r1, #0x12		@ XN|U + section mapping/*SH Section 속성  XN[4]=0b1,1[1]=0b1*/
		orr	r1, r1, #3 << 10	@ AP=11			/*SH Section 속성 AP[11:10] = 0b11.*/
									/*SH 루프 들어가기 전 최종 Section 속성 : 0xC12*/
									/*SH 0xC12 -> AP[11:10] = 0b11, XN = 0b1, 1 = 0b1*/
		add	r2, r3, #16384					/*SH r2 = page directory 끝 주소값 : 루프 종료조건*/
1:		cmp	r1, r9			@ if virt > start of RAM/*SH Section base address가 RAM인지 검사*/
		cmphs	r10, r1			@   && end of RAM > virt
		bic	r1, r1, #0x1c		@ clear XN|U + C + B	/*SH Section 속성값 초기화*/
		orrlo	r1, r1, #0x10		@ Set XN|U for non-RAM	/*SH 위 if 조건 false : non-RAM Section 속성은 XN=0b1 -> 0xC12*/
		orrhs	r1, r1, r6		@ set RAM section settings/*SH 위 if 조건이 true : RAM Section 속성은 r6=#CB_BITS|0x02 : C=0b1,B=0b1,1=0b1 -> 0xC0E*/
		str	r1, [r0], #4		@ 1:1 mapping		/*SH r0 = 0xXX004000 을 시작으로 Section(r1) 저장 후 r0+=4(주소값 + 4)*/
		add	r1, r1, #1048576				/*SH 다음 Section base address 셋팅 : 1M단위이다*/
		teq	r0, r2						/*SH r0가 0xXX008000인지 검사*/
		bne	1b						/*SH 0xXX008000이 아니면 라벨'1'로 분기*/
/*
 * If ever we are running from Flash, then we surely want the cache
 * to be enabled also for our execution instance...  We map 2MB of it
 * so there is no map overlap problem for up to 1 MB compressed kernel.
 * If the execution is in RAM then we would only be duplicating the above.
 */
/*SH 130906
 * Flash에서 바로 실행 될 경우 를 대비하여 현재 주소영역(pc)에 대한 Section 속성을 RAM 영역과 같이(cacheable, bufferable) 지정해 주어야한다.
 * 1MB이상의 압축된 커널에 대해 no map overlap problem 땜시 2MB 영역의 Section을 맵핑한다.
 * 만약 현재 주소 영역이 RAM이라고 하더라도(RAM에서 실행중이라면) 이미 셋팅한 값을 똑같이 셋팅할 뿐이다.
 * */
		orr	r1, r6, #0x04		@ ensure B is set for this  /*SH r1=(#CB_BITS|0x02|0x04)*/
		orr	r1, r1, #3 << 10	/*SH r1 |= AP[11:10] : 0b11*/
						/*SH Section 속성(r1) : 0xC0E*/
		mov	r2, pc
		mov	r2, r2, lsr #20
		orr	r1, r1, r2, lsl #20	/*SH r1 = 현재 주소영역(pc)에서 Section base address + Section 속성 값*/
		add	r0, r3, r2, lsl #2	/*SH r0 = 0xXX004000 + Section directory에서 현재 주소영역에 대한 Section table위치*/
		str	r1, [r0], #4		/*SH Section 저장*/
		add	r1, r1, #1048576	/*SH 2MB영역 지정위해 Section base address + 1MB*/
		str	r1, [r0]		/*SH Section 저장*/
		mov	pc, lr
ENDPROC(__setup_mmu)

@ Enable unaligned access on v6, to allow better code generation
@ for the decompressor C code:
__armv6_mmu_cache_on:
		mrc	p15, 0, r0, c1, c0, 0	@ read SCTLR
		bic	r0, r0, #2		@ A (no unaligned access fault)
		orr	r0, r0, #1 << 22	@ U (v6 unaligned access model)
		mcr	p15, 0, r0, c1, c0, 0	@ write SCTLR
		b	__armv4_mmu_cache_on

__arm926ejs_mmu_cache_on:
#ifdef CONFIG_CPU_DCACHE_WRITETHROUGH
		mov	r0, #4			@ put dcache in WT mode
		mcr	p15, 7, r0, c15, c0, 0
#endif

__armv4_mmu_cache_on:
		mov	r12, lr
#ifdef CONFIG_MMU
		mov	r6, #CB_BITS | 0x12	@ U
		bl	__setup_mmu
		mov	r0, #0
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer
		mcr	p15, 0, r0, c8, c7, 0	@ flush I,D TLBs
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg
		orr	r0, r0, #0x5000		@ I-cache enable, RR cache replacement
		orr	r0, r0, #0x0030
#ifdef CONFIG_CPU_ENDIAN_BE8
		orr	r0, r0, #1 << 25	@ big-endian page tables
#endif
		bl	__common_mmu_cache_on
		mov	r0, #0
		mcr	p15, 0, r0, c8, c7, 0	@ flush I,D TLBs
#endif
		mov	pc, r12

__armv7_mmu_cache_on:
		mov	r12, lr			/*SH r12 = lr : __setup_mmu로 분기할때 lr을 써야 하므로 r12에 현재 lr을 저장한다.*/
#ifdef CONFIG_MMU	/*SH Y*/
		mrc	p15, 0, r11, c0, c1, 4	@ read ID_MMFR0	/*SH A.R.M B4.1.89 ID_MMFR0, Memory Model Feature Register 0, VMSA*/
		tst	r11, #0xf		@ VMSA		/*SH VMSA support[3:0] 필드를 검사 : 0x0만 아니면 뭔가 지원되는 것임*/
								/*SH A.R.M에 보면 현재 분석중인 ARMv7-a는 0b0011(0x03) 일 가능성이 큼*/
		movne	r6, #CB_BITS | 0x02	@ !XN		/*SH VMSA 지원하면 r6 = #CB_BITS | 0x02*/
		blne	__setup_mmu				/*SH VMSA 지원하면 lr='mov r0, #0'명령어주소값 후 __setup_mmu로 분기*/
		mov	r0, #0
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer/*SH A.R.M B4.1.38 CP15DSB, CP15 Data Synchronization Barrier operation, VMSA*/
		tst	r11, #0xf		@ VMSA
		mcrne	p15, 0, r0, c8, c7, 0	@ flush I,D TLBs    /*SH VMSA 지원하면 A.R.M B4.1.135 TLBIALL, TLB Invalidate All, VMSA only*/
#endif
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg  /*SH A.R.M B4.1.130 SCTLR, System Control Register, VMSA*/
		bic	r0, r0, #1 << 28	@ clear SCTLR.TRE   /*SH TEX remap disabled*/
		orr	r0, r0, #0x5000		@ I-cache enable, RR cache replacement
		orr	r0, r0, #0x003c		@ write buffer	    /*SH CP15 barrier enable, Data and unified caches enabled*/
		bic	r0, r0, #2		@ A (no unaligned access fault)	/*SH Alignment check enable*/
		orr	r0, r0, #1 << 22	@ U (v6 unaligned access model)	/*SH In ARMv7 this bit is RAO/SBOP FIXME : 이건뭐지?*/
						@ (needed for ARM1176)
#ifdef CONFIG_MMU	/*SH Y*/
#ifdef CONFIG_CPU_ENDIAN_BE8	/*SH N*/
		orr	r0, r0, #1 << 25	@ big-endian page tables
#endif
		mrcne   p15, 0, r6, c2, c0, 2   @ read ttb control reg	/*SH VMSA 지원하면 A.R.M B4.1.153 TTBCR, Translation Table Base Control Register, VMSA*/
		orrne	r0, r0, #1		@ MMU enabled		/*SH SCTLR에 셋팅임*/
		movne	r1, #0xfffffffd		@ domain 0 = client	/*SH domain 0 = client, domain 1~15 = Manager*/
		bic     r6, r6, #1 << 31        @ 32-bit translation system
		bic     r6, r6, #3 << 0         @ use only ttbr0
		mcrne	p15, 0, r3, c2, c0, 0	@ load page table pointer   /*SH VMSA 지원하면 A.R.M B4.1.154 TTBR0, Translation Table Base Register 0, VMSA*/
									    /*SH TTBR0에 0xXX004000(r3) 저장*/
		mcrne	p15, 0, r1, c3, c0, 0	@ load domain access control/*SH VMSA 지원하면 A.R.M B4.1.43 DACR, Domain Access Control Register, VMSA*/
									    /*SH A.R.M에는 'mcrne   p15, 0, r1, c3, c0, 0' -> 'mcrne   p15, 0, r1, c3, c0, 1'*/
		mcrne   p15, 0, r6, c2, c0, 2   @ load ttb control
#endif
		mcr	p15, 0, r0, c7, c5, 4	@ ISB			/*SH A.R.M B4.1.39 CP15ISB, CP15 Instruction Synchronization Barrier operation, VMSA*/
		mcr	p15, 0, r0, c1, c0, 0	@ load control register
		mrc	p15, 0, r0, c1, c0, 0	@ and read it back	/*SH FIXME 왜 또 읽어?*/
		mov	r0, #0						/*SH r0 = 0 : return 0*/
		mcr	p15, 0, r0, c7, c5, 4	@ ISB
		mov	pc, r12						/*SH r12 = 시작시 저장한 복귀주소*/

__fa526_cache_on:
		mov	r12, lr
		mov	r6, #CB_BITS | 0x12	@ U
		bl	__setup_mmu
		mov	r0, #0
		mcr	p15, 0, r0, c7, c7, 0	@ Invalidate whole cache
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer
		mcr	p15, 0, r0, c8, c7, 0	@ flush UTLB
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg
		orr	r0, r0, #0x1000		@ I-cache enable
		bl	__common_mmu_cache_on
		mov	r0, #0
		mcr	p15, 0, r0, c8, c7, 0	@ flush UTLB
		mov	pc, r12

__common_mmu_cache_on:
#ifndef CONFIG_THUMB2_KERNEL
#ifndef DEBUG
		orr	r0, r0, #0x000d		@ Write buffer, mmu
#endif
		mov	r1, #-1
		mcr	p15, 0, r3, c2, c0, 0	@ load page table pointer
		mcr	p15, 0, r1, c3, c0, 0	@ load domain access control
		b	1f
		.align	5			@ cache line aligned
1:		mcr	p15, 0, r0, c1, c0, 0	@ load control register
		mrc	p15, 0, r0, c1, c0, 0	@ and read it back to
		sub	pc, lr, r0, lsr #32	@ properly flush pipeline
#endif

#define PROC_ENTRY_SIZE (4*5)

/*
 * Here follow the relocatable cache support functions for the
 * various processors.  This is a generic hook for locating an
 * entry and jumping to an instruction at the specified offset
 * from the start of the block.  Please note this is all position
 * independent code.
 *
 *  r1  = corrupted
 *  r2  = corrupted
 *  r3  = block offset
 *  r9  = corrupted
 *  r12 = corrupted
 */

/*SH 130905
 * call_cach_fn : processor ID를 읽어온 후, proc_types 구조체 배열을 차례대로 읽어와 processor ID에 맞는 cache 연산 함수를 호출해 준다.
 * 이때, r3 값이 어떤 cache 연산 함수를 호출 할지 결정한다.
 * r3 = 8 -> cache_on 호출
 * r3 = 12 -> cache_off 호출
 * r3 = 16 -> cache_flush 호출
 * 된다.
 * */
call_cache_fn:	adr	r12, proc_types		/*SH r12 = 라벨 'proc_types'의 주소값*/
#ifdef CONFIG_CPU_CP15	/*SH Y*/
		mrc	p15, 0, r9, c0, c0	@ get processor ID	/*SH A.R.M B4.1.105 MIDR, Main ID Register, VMSA*/
									/*SH r9 = MIDR*/
									/*SH MIDR 필드중 [19:16] Architecture 필드를 조사*/
									/*SH 현재 ARMv7 분석중이니 : 0xF 값이 될것이다.*/
#else
		ldr	r9, =CONFIG_PROCESSOR_ID
#endif
/*SH 130905
 * ARMv7의 proc_types는
.word	0x000f0000		@ new CPU Id
.word	0x000f0000
W(b)	__armv7_mmu_cache_on
W(b)	__armv7_mmu_cache_off
W(b)	__armv7_mmu_cache_flush
 * 이다.
 * */
1:		ldr	r1, [r12, #0]		@ get value
		ldr	r2, [r12, #4]		@ get mask
		eor	r1, r1, r9		@ (real ^ match)
		tst	r1, r2			@       & mask
 ARM(		addeq	pc, r12, r3		) @ call cache function
 THUMB(		addeq	r12, r3			)
 THUMB(		moveq	pc, r12			) @ call cache function
		add	r12, r12, #PROC_ENTRY_SIZE
		b	1b

/*
 * Table for cache operations.  This is basically:
 *   - CPU ID match
 *   - CPU ID mask
 *   - 'cache on' method instruction
 *   - 'cache off' method instruction
 *   - 'cache flush' method instruction
 *
 * We match an entry using: ((real_id ^ match) & mask) == 0
 *
 * Writethrough caches generally only need 'on' and 'off'
 * methods.  Writeback caches _must_ have the flush method
 * defined.
 */
		.align	2
		.type	proc_types,#object
proc_types:
		.word	0x41000000		@ old ARM ID
		.word	0xff00f000
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)

		.word	0x41007000		@ ARM7/710
		.word	0xfff8fe00
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)

		.word	0x41807200		@ ARM720T (writethrough)
		.word	0xffffff00
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		mov	pc, lr
 THUMB(		nop				)

		.word	0x41007400		@ ARM74x
		.word	0xff00ff00
		W(b)	__armv3_mpu_cache_on
		W(b)	__armv3_mpu_cache_off
		W(b)	__armv3_mpu_cache_flush
		
		.word	0x41009400		@ ARM94x
		.word	0xff00ff00
		W(b)	__armv4_mpu_cache_on
		W(b)	__armv4_mpu_cache_off
		W(b)	__armv4_mpu_cache_flush

		.word	0x41069260		@ ARM926EJ-S (v5TEJ)
		.word	0xff0ffff0
		W(b)	__arm926ejs_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv5tej_mmu_cache_flush

		.word	0x00007000		@ ARM7 IDs
		.word	0x0000f000
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)

		@ Everything from here on will be the new ID system.

		.word	0x4401a100		@ sa110 / sa1100
		.word	0xffffffe0
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x6901b110		@ sa1110
		.word	0xfffffff0
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x56056900
		.word	0xffffff00		@ PXA9xx
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x56158000		@ PXA168
		.word	0xfffff000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv5tej_mmu_cache_flush

		.word	0x56050000		@ Feroceon
		.word	0xff0f0000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv5tej_mmu_cache_flush

#ifdef CONFIG_CPU_FEROCEON_OLD_ID
		/* this conflicts with the standard ARMv5TE entry */
		.long	0x41009260		@ Old Feroceon
		.long	0xff00fff0
		b	__armv4_mmu_cache_on
		b	__armv4_mmu_cache_off
		b	__armv5tej_mmu_cache_flush
#endif

		.word	0x66015261		@ FA526
		.word	0xff01fff1
		W(b)	__fa526_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__fa526_cache_flush

		@ These match on the architecture ID

		.word	0x00020000		@ ARMv4T
		.word	0x000f0000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x00050000		@ ARMv5TE
		.word	0x000f0000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x00060000		@ ARMv5TEJ
		.word	0x000f0000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv5tej_mmu_cache_flush

		.word	0x0007b000		@ ARMv6
		.word	0x000ff000
		W(b)	__armv6_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv6_mmu_cache_flush

		.word	0x000f0000		@ new CPU Id
		.word	0x000f0000
		W(b)	__armv7_mmu_cache_on
		W(b)	__armv7_mmu_cache_off
		W(b)	__armv7_mmu_cache_flush

		.word	0			@ unrecognised type
		.word	0
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)

		.size	proc_types, . - proc_types

		/*
		 * If you get a "non-constant expression in ".if" statement"
		 * error from the assembler on this line, check that you have
		 * not accidentally written a "b" instruction where you should
		 * have written W(b).
		 */
		.if (. - proc_types) % PROC_ENTRY_SIZE != 0
		.error "The size of one or more proc_types entries is wrong."
		.endif

/*
 * Turn off the Cache and MMU.  ARMv3 does not support
 * reading the control register, but ARMv4 does.
 *
 * On exit,
 *  r0, r1, r2, r3, r9, r12 corrupted
 * This routine must preserve:
 *  r4, r7, r8
 */
		.align	5
cache_off:	mov	r3, #12			@ cache_off function
		b	call_cache_fn

__armv4_mpu_cache_off:
		mrc	p15, 0, r0, c1, c0
		bic	r0, r0, #0x000d
		mcr	p15, 0, r0, c1, c0	@ turn MPU and cache off
		mov	r0, #0
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer
		mcr	p15, 0, r0, c7, c6, 0	@ flush D-Cache
		mcr	p15, 0, r0, c7, c5, 0	@ flush I-Cache
		mov	pc, lr

__armv3_mpu_cache_off:
		mrc	p15, 0, r0, c1, c0
		bic	r0, r0, #0x000d
		mcr	p15, 0, r0, c1, c0, 0	@ turn MPU and cache off
		mov	r0, #0
		mcr	p15, 0, r0, c7, c0, 0	@ invalidate whole cache v3
		mov	pc, lr

__armv4_mmu_cache_off:
#ifdef CONFIG_MMU
		mrc	p15, 0, r0, c1, c0
		bic	r0, r0, #0x000d
		mcr	p15, 0, r0, c1, c0	@ turn MMU and cache off
		mov	r0, #0
		mcr	p15, 0, r0, c7, c7	@ invalidate whole cache v4
		mcr	p15, 0, r0, c8, c7	@ invalidate whole TLB v4
#endif
		mov	pc, lr

__armv7_mmu_cache_off:
		mrc	p15, 0, r0, c1, c0
#ifdef CONFIG_MMU
		bic	r0, r0, #0x000d
#else
		bic	r0, r0, #0x000c
#endif
		mcr	p15, 0, r0, c1, c0	@ turn MMU and cache off
		mov	r12, lr
		bl	__armv7_mmu_cache_flush
		mov	r0, #0
#ifdef CONFIG_MMU
		mcr	p15, 0, r0, c8, c7, 0	@ invalidate whole TLB
#endif
		mcr	p15, 0, r0, c7, c5, 6	@ invalidate BTC
		mcr	p15, 0, r0, c7, c10, 4	@ DSB
		mcr	p15, 0, r0, c7, c5, 4	@ ISB
		mov	pc, r12

/*
 * Clean and flush the cache to maintain consistency.
 *
 * On exit,
 *  r1, r2, r3, r9, r10, r11, r12 corrupted
 * This routine must preserve:
 *  r4, r6, r7, r8
 */
		.align	5
cache_clean_flush:
		mov	r3, #16
		b	call_cache_fn

__armv4_mpu_cache_flush:
		mov	r2, #1
		mov	r3, #0
		mcr	p15, 0, ip, c7, c6, 0	@ invalidate D cache
		mov	r1, #7 << 5		@ 8 segments
1:		orr	r3, r1, #63 << 26	@ 64 entries
2:		mcr	p15, 0, r3, c7, c14, 2	@ clean & invalidate D index
		subs	r3, r3, #1 << 26
		bcs	2b			@ entries 63 to 0
		subs 	r1, r1, #1 << 5
		bcs	1b			@ segments 7 to 0

		teq	r2, #0
		mcrne	p15, 0, ip, c7, c5, 0	@ invalidate I cache
		mcr	p15, 0, ip, c7, c10, 4	@ drain WB
		mov	pc, lr
		
__fa526_cache_flush:
		mov	r1, #0
		mcr	p15, 0, r1, c7, c14, 0	@ clean and invalidate D cache
		mcr	p15, 0, r1, c7, c5, 0	@ flush I cache
		mcr	p15, 0, r1, c7, c10, 4	@ drain WB
		mov	pc, lr

__armv6_mmu_cache_flush:
		mov	r1, #0
		mcr	p15, 0, r1, c7, c14, 0	@ clean+invalidate D
		mcr	p15, 0, r1, c7, c5, 0	@ invalidate I+BTB
		mcr	p15, 0, r1, c7, c15, 0	@ clean+invalidate unified
		mcr	p15, 0, r1, c7, c10, 4	@ drain WB
		mov	pc, lr

__armv7_mmu_cache_flush:
		mrc	p15, 0, r10, c0, c1, 5	@ read ID_MMFR1
		tst	r10, #0xf << 16		@ hierarchical cache (ARMv7)
		mov	r10, #0
		beq	hierarchical
		mcr	p15, 0, r10, c7, c14, 0	@ clean+invalidate D
		b	iflush
hierarchical:
		mcr	p15, 0, r10, c7, c10, 5	@ DMB
		stmfd	sp!, {r0-r7, r9-r11}
		mrc	p15, 1, r0, c0, c0, 1	@ read clidr
		ands	r3, r0, #0x7000000	@ extract loc from clidr
		mov	r3, r3, lsr #23		@ left align loc bit field
		beq	finished		@ if loc is 0, then no need to clean
		mov	r10, #0			@ start clean at cache level 0
loop1:
		add	r2, r10, r10, lsr #1	@ work out 3x current cache level
		mov	r1, r0, lsr r2		@ extract cache type bits from clidr
		and	r1, r1, #7		@ mask of the bits for current cache only
		cmp	r1, #2			@ see what cache we have at this level
		blt	skip			@ skip if no cache, or just i-cache
		mcr	p15, 2, r10, c0, c0, 0	@ select current cache level in cssr
		mcr	p15, 0, r10, c7, c5, 4	@ isb to sych the new cssr&csidr
		mrc	p15, 1, r1, c0, c0, 0	@ read the new csidr
		and	r2, r1, #7		@ extract the length of the cache lines
		add	r2, r2, #4		@ add 4 (line length offset)
		ldr	r4, =0x3ff
		ands	r4, r4, r1, lsr #3	@ find maximum number on the way size
		clz	r5, r4			@ find bit position of way size increment
		ldr	r7, =0x7fff
		ands	r7, r7, r1, lsr #13	@ extract max number of the index size
loop2:
		mov	r9, r4			@ create working copy of max way size
loop3:
 ARM(		orr	r11, r10, r9, lsl r5	) @ factor way and cache number into r11
 ARM(		orr	r11, r11, r7, lsl r2	) @ factor index number into r11
 THUMB(		lsl	r6, r9, r5		)
 THUMB(		orr	r11, r10, r6		) @ factor way and cache number into r11
 THUMB(		lsl	r6, r7, r2		)
 THUMB(		orr	r11, r11, r6		) @ factor index number into r11
		mcr	p15, 0, r11, c7, c14, 2	@ clean & invalidate by set/way
		subs	r9, r9, #1		@ decrement the way
		bge	loop3
		subs	r7, r7, #1		@ decrement the index
		bge	loop2
skip:
		add	r10, r10, #2		@ increment cache number
		cmp	r3, r10
		bgt	loop1
finished:
		ldmfd	sp!, {r0-r7, r9-r11}
		mov	r10, #0			@ swith back to cache level 0
		mcr	p15, 2, r10, c0, c0, 0	@ select current cache level in cssr
iflush:
		mcr	p15, 0, r10, c7, c10, 4	@ DSB
		mcr	p15, 0, r10, c7, c5, 0	@ invalidate I+BTB
		mcr	p15, 0, r10, c7, c10, 4	@ DSB
		mcr	p15, 0, r10, c7, c5, 4	@ ISB
		mov	pc, lr

__armv5tej_mmu_cache_flush:
1:		mrc	p15, 0, r15, c7, c14, 3	@ test,clean,invalidate D cache
		bne	1b
		mcr	p15, 0, r0, c7, c5, 0	@ flush I cache
		mcr	p15, 0, r0, c7, c10, 4	@ drain WB
		mov	pc, lr

__armv4_mmu_cache_flush:
		mov	r2, #64*1024		@ default: 32K dcache size (*2)
		mov	r11, #32		@ default: 32 byte line size
		mrc	p15, 0, r3, c0, c0, 1	@ read cache type
		teq	r3, r9			@ cache ID register present?
		beq	no_cache_id
		mov	r1, r3, lsr #18
		and	r1, r1, #7
		mov	r2, #1024
		mov	r2, r2, lsl r1		@ base dcache size *2
		tst	r3, #1 << 14		@ test M bit
		addne	r2, r2, r2, lsr #1	@ +1/2 size if M == 1
		mov	r3, r3, lsr #12
		and	r3, r3, #3
		mov	r11, #8
		mov	r11, r11, lsl r3	@ cache line size in bytes
no_cache_id:
		mov	r1, pc
		bic	r1, r1, #63		@ align to longest cache line
		add	r2, r1, r2
1:
 ARM(		ldr	r3, [r1], r11		) @ s/w flush D cache
 THUMB(		ldr     r3, [r1]		) @ s/w flush D cache
 THUMB(		add     r1, r1, r11		)
		teq	r1, r2
		bne	1b

		mcr	p15, 0, r1, c7, c5, 0	@ flush I cache
		mcr	p15, 0, r1, c7, c6, 0	@ flush D cache
		mcr	p15, 0, r1, c7, c10, 4	@ drain WB
		mov	pc, lr

__armv3_mmu_cache_flush:
__armv3_mpu_cache_flush:
		mov	r1, #0
		mcr	p15, 0, r1, c7, c0, 0	@ invalidate whole cache v3
		mov	pc, lr

/*
 * Various debugging routines for printing hex characters and
 * memory, which again must be relocatable.
 */
#ifdef DEBUG
		.align	2
		.type	phexbuf,#object
phexbuf:	.space	12
		.size	phexbuf, . - phexbuf

@ phex corrupts {r0, r1, r2, r3}
phex:		adr	r3, phexbuf
		mov	r2, #0
		strb	r2, [r3, r1]
1:		subs	r1, r1, #1
		movmi	r0, r3
		bmi	puts
		and	r2, r0, #15
		mov	r0, r0, lsr #4
		cmp	r2, #10
		addge	r2, r2, #7
		add	r2, r2, #'0'
		strb	r2, [r3, r1]
		b	1b

@ puts corrupts {r0, r1, r2, r3}
puts:		loadsp	r3, r1
1:		ldrb	r2, [r0], #1
		teq	r2, #0
		moveq	pc, lr
2:		writeb	r2, r3
		mov	r1, #0x00020000
3:		subs	r1, r1, #1
		bne	3b
		teq	r2, #'\n'
		moveq	r2, #'\r'
		beq	2b
		teq	r0, #0
		bne	1b
		mov	pc, lr
@ putc corrupts {r0, r1, r2, r3}
putc:
		mov	r2, r0
		mov	r0, #0
		loadsp	r3, r1
		b	2b

@ memdump corrupts {r0, r1, r2, r3, r10, r11, r12, lr}
memdump:	mov	r12, r0
		mov	r10, lr
		mov	r11, #0
2:		mov	r0, r11, lsl #2
		add	r0, r0, r12
		mov	r1, #8
		bl	phex
		mov	r0, #':'
		bl	putc
1:		mov	r0, #' '
		bl	putc
		ldr	r0, [r12, r11, lsl #2]
		mov	r1, #8
		bl	phex
		and	r0, r11, #7
		teq	r0, #3
		moveq	r0, #' '
		bleq	putc
		and	r0, r11, #7
		add	r11, r11, #1
		teq	r0, #7
		bne	1b
		mov	r0, #'\n'
		bl	putc
		cmp	r11, #64
		blt	2b
		mov	pc, r10
#endif

		.ltorg

#ifdef CONFIG_ARM_VIRT_EXT
.align 5
__hyp_reentry_vectors:
		W(b)	.			@ reset
		W(b)	.			@ undef
		W(b)	.			@ svc
		W(b)	.			@ pabort
		W(b)	.			@ dabort
		W(b)	__enter_kernel		@ hyp
		W(b)	.			@ irq
		W(b)	.			@ fiq
#endif /* CONFIG_ARM_VIRT_EXT */

__enter_kernel:
		mov	r0, #0			@ must be 0
 ARM(		mov	pc, r4	)		@ call kernel
 THUMB(		bx	r4	)		@ entry point is always ARM

reloc_code_end:

		.align
		.section ".stack", "aw", %nobits
.L_user_stack:	.space	4096
.L_user_stack_end:
