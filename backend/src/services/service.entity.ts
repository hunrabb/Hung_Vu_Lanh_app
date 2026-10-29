export class Service {
  id!: string;
  categoryId!: string;
  name!: string;
  // The API exposes integer VND as a string to preserve exact values.
  price!: string;
  duration!: number;
  isActive!: boolean;
}
