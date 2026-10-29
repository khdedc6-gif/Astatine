using System.Collections.Generic;
using UnityEngine;

// Structure định nghĩa 1 Chai / Lọ Hóa chất
[System.Serializable]
public class BottleItem
{
    public string id;              // Mã định danh (VD: "bot_hcl")
    public string displayName;     // Tên hiển thị (VD: "Dung dịch HCl 1M")
    public string chemicalFormula; // Công thức (VD: "HCl")
    public float defaultVolume;    // Thể tích mặc định (ml)
    public float pH;               // Nồng độ pH
    public Color liquidColor;      // Màu đặc trưng
    public string prefabPath;      // Đường dẫn Prefab Model 3D trong thư mục Resources
}

public class LabDatabaseRegistry : MonoBehaviour
{
    public static LabDatabaseRegistry Instance;
    public const string DefaultBottleId = "bot_naoh";

    // Kho lưu trữ danh sách các chai lọ hóa chất có sẵn
    public Dictionary<string, BottleItem> bottleDatabase = new Dictionary<string, BottleItem>();

    private void Awake()
    {
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
            InitializeBottleDatabase();
        }
        else
        {
            Destroy(gameObject);
        }
    }

    // --- KHAI BÁO TẤT CẢ CHAI LỌ & HÓA CHẤT TRONG VS CODE TẠI ĐÂY ---
   private void InitializeBottleDatabase()
{
    // 1. Bình Cốc Flask_01 (Axit HCl)
    RegisterBottle(new BottleItem
    {
        id = "bot_hcl",
        displayName = "Bình Axit HCl 1M",
        chemicalFormula = "HCl",
        defaultVolume = 250f,
        pH = 1.0f,
        liquidColor = new Color(0.9f, 0.95f, 1f, 0.2f),
        prefabPath = "LabProps/Bottles/Flask_01" // Tự tải Flask_01
    });

    // 2. Bình Flask_05 (Bazơ NaOH)
    RegisterBottle(new BottleItem
    {
        id = "bot_naoh",
        displayName = "Bình NaOH 1M",
        chemicalFormula = "NaOH",
        defaultVolume = 250f,
        pH = 13.0f,
        liquidColor = new Color(0.95f, 0.95f, 1f, 0.2f),
        prefabPath = "LabProps/Bottles/Flask_05" // Tự tải Flask_05
    });

    // 3. Ống nhỏ giọt Pipette (Phenolphthalein)
    RegisterBottle(new BottleItem
    {
        id = "bot_phenolphthalein",
        displayName = "Ống Phenolphthalein",
        chemicalFormula = "Phenolphthalein",
        defaultVolume = 20f,
        pH = 7.0f,
        liquidColor = new Color(1f, 1f, 1f, 0.05f),
        prefabPath = "LabProps/Bottles/Pipette" // Tự tải Pipette
    });
}

    private void RegisterBottle(BottleItem item)
    {
        if (!bottleDatabase.ContainsKey(item.id))
        {
            bottleDatabase.Add(item.id, item);
        }
    }

    // --- HÀM TỰ ĐỘNG SPAWN CHAI LỌ RA BÀN THÍ NGHIỆM BẰNG CODE ---
    public GameObject SpawnBottleToTable(string bottleId, Vector3 spawnPosition)
    {
        if (!bottleDatabase.ContainsKey(bottleId))
        {
            Debug.LogError($"Không tìm thấy ID chai lọ: {bottleId}");
            return null;
        }

        BottleItem data = bottleDatabase[bottleId];

        // Tải Model 3D từ thư mục Resources
        GameObject prefab = Resources.Load<GameObject>(data.prefabPath);
        if (prefab == null)
        {
            // Nếu chưa bỏ Asset 3D vào Resources thì tự sinh Cylinder chữa cháy
            prefab = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        }

        GameObject newBottle = Instantiate(prefab, spawnPosition, Quaternion.identity);
        newBottle.name = data.displayName;

        // Tự động gán/cập nhật Container3D
        Container3D container = newBottle.GetComponent<Container3D>();
        if (container == null) container = newBottle.AddComponent<Container3D>();

        container.containerName = data.displayName;
        container.maxCapacity = data.defaultVolume;
        container.currentVolume = data.defaultVolume;
        container.currentpH = data.pH;

        return newBottle;
    }

    public GameObject SpawnDefaultBottleToTable(Vector3 spawnPosition)
    {
        return SpawnBottleToTable(DefaultBottleId, spawnPosition);
    }
}