package main

type MyExternals struct {
}

//func (MyExternals) average(nums []int64) int64 {
//	total := int64(0)
//	for _, x := range nums {
//		total += x
//	}
//	return total / int64(len(nums))
//}

func main() {
	my_server := NewServer(MyExternals{})
	my_server.run()
}
