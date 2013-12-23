#ifndef _LINUX_NUMA_H
#define _LINUX_NUMA_H


#ifdef CONFIG_NODES_SHIFT	/*SH N*/
#define NODES_SHIFT     CONFIG_NODES_SHIFT
#else	/*SH this*/
#define NODES_SHIFT     0	/*SH this*/
#endif

#define MAX_NUMNODES    (1 << NODES_SHIFT)

#define	NUMA_NO_NODE	(-1)

#endif /* _LINUX_NUMA_H */
