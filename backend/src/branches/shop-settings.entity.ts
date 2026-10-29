// Calendar dates remain YYYY-MM-DD strings in Firestore.
export class ShopSettings {
  branchId!: string;
  id!: string;
  openingMinute!: number;
  closingMinute!: number;
  closedWeekdays!: number[];
  closedDates!: string[];
}
