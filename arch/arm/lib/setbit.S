/*
 *  linux/arch/arm/lib/setbit.S
 *
 *  Copyright (C) 1995-1996 Russell King
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */
#include <linux/linkage.h>
#include <asm/assembler.h>
#include "bitops.h"
		.text

bitop	_set_bit, orr	/*SH bitop 매크로를 이용하여  _set_bit 루틴 정의*//*SH 원자적 연산을 한다.*/
